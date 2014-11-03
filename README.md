# node-bump

[![Build Status](https://secure.travis-ci.org/kilianc/node-bump.png)](https://travis-ci.org/kilianc/node-bump)

nodejs version bumper

## Install

`npm install -g bump`

# Basic Usage

    usage: bump [version]

# Usage

    usage: bump [options]

  Options:

    -h, --help                  output usage information
    -V, --version               output the version number
    -q, --quiet                 quiet mode
    -v, --verbose               verbose mode
    -p, --patch                 bump patch version [default]
    -m, --minor                 bump minor version
    -M, --major                 bump major version
    -t, --to <version>          explicit version to bump to
    -b, --bump [name]           package property to bump: [version]
    -d, --dependency [package]  what (dev?)dependency to bump
    -l, --latest                for a package dependency, bump to latest version
    -B, --beta                  for a package dependency, bump to latest beta
    -f, --force                 proceeds even if the given version is a bump backwards
    -n, --no-edit               do not actually write package.json; just simulate it
