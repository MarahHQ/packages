# Marah packages

The DNF and APT repositories for [Marah Launcher](https://github.com/MarahHQ/marah-launcher),
on GitHub Pages: https://marahhq.github.io/packages. How to add them is on that page.

`.github/workflows/publish.yml` rebuilds them daily, by hand, and when the Marah Bot starts it
after a release, from the rpm and deb of the latest three releases (`scripts/build-repo.sh`).
The metadata is signed with the organization secret `PACKAGES_SIGNING_KEY`. The packages take
libmpv from the system, which keeps each one about 50 MB, under GitHub Pages' 100 MB file limit.
