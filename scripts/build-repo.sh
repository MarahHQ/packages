#!/usr/bin/env bash
# Builds the DNF and APT repositories for Marah Launcher into a folder, from the rpm and deb of
# its latest releases (KEEP, default 3), signed with the GPG key in GNUPGHOME:
#   scripts/build-repo.sh <out folder> <key id>
# Needs gh (GH_TOKEN), createrepo_c, apt-ftparchive and gpg.
#   <out>/rpm/            the rpms, repodata/ with repomd.xml.asc, and marah.repo
#   <out>/deb/            pool/ with the debs, dists/stable/ with Release, InRelease, Release.gpg
#   <out>/marah.asc       the public key both check against
set -euo pipefail
out="${1:?usage: $0 <out folder> <key id>}"
key="${2:?key id}"
repo=MarahHQ/marah-launcher
keep="${KEEP:-3}"
mkdir -p "$out/rpm" "$out/deb/pool/main" "$out/deb/dists/stable/main/binary-amd64"

# The newest releases that have packages, newest first. Drafts and pre-releases stay out.
gh release list -R "$repo" --exclude-drafts --exclude-pre-releases --limit 20 --json tagName -q '.[].tagName' |
    head -n "$keep" | while read -r tag; do
    gh release download "$tag" -R "$repo" --dir "$out/rpm" --skip-existing \
        --pattern 'marah-launcher-*.x86_64.rpm' --pattern 'marah-launcher-*.x86_64.rpm.sha256'
    gh release download "$tag" -R "$repo" --dir "$out/deb/pool/main" --skip-existing \
        --pattern 'marah-launcher_*_amd64.deb' --pattern 'marah-launcher_*_amd64.deb.sha256'
done
(cd "$out/rpm" && sha256sum -c ./*.sha256 && rm ./*.sha256)
(cd "$out/deb/pool/main" && sha256sum -c ./*.sha256 && rm ./*.sha256)
ls "$out"/rpm/*.rpm "$out"/deb/pool/main/*.deb > /dev/null

gpg --armor --export "$key" > "$out/marah.asc"

# DNF: the metadata is signed (repo_gpgcheck); its checksums cover each package.
createrepo_c --quiet "$out/rpm"
gpg --batch --yes --local-user "$key" --detach-sign --armor "$out/rpm/repodata/repomd.xml"
cat > "$out/rpm/marah.repo" <<'REPO'
[marah]
name=Marah
baseurl=https://marahhq.github.io/packages/rpm
enabled=1
gpgcheck=0
repo_gpgcheck=1
gpgkey=https://marahhq.github.io/packages/marah.asc
# Read the repo again after an hour, not dnf's default: a new release shows at the next update.
metadata_expire=1h
REPO

# APT: one suite, stable, with the Release file signed both ways.
(
    cd "$out/deb"
    apt-ftparchive packages pool > dists/stable/main/binary-amd64/Packages
    gzip -9kf dists/stable/main/binary-amd64/Packages
    apt-ftparchive -o APT::FTPArchive::Release::Origin=Marah -o APT::FTPArchive::Release::Label=Marah \
        -o APT::FTPArchive::Release::Suite=stable -o APT::FTPArchive::Release::Codename=stable \
        -o APT::FTPArchive::Release::Architectures=amd64 -o APT::FTPArchive::Release::Components=main \
        release dists/stable > dists/stable/Release
    gpg --batch --yes --local-user "$key" --clearsign -o dists/stable/InRelease dists/stable/Release
    gpg --batch --yes --local-user "$key" --detach-sign --armor -o dists/stable/Release.gpg dists/stable/Release
)
cp index.html "$out/"
echo "built $out: $(ls "$out"/rpm/*.rpm | wc -l) rpm, $(ls "$out"/deb/pool/main/*.deb | wc -l) deb"
