#! /usr/bin/env coffee

fs = require 'fs'

semver = require 'semver'
request = require 'request'
format = require 'format-json'
program = require 'commander'

raw = fs.readFileSync('package.json', 'utf8')
pkg = JSON.parse(raw)

log = (args...) ->
  console.log args...  if program.verbose and !program.quiet

fail = (exitCode, args...) ->
  if typeof exitCode isnt 'number'
    args.unshift exitCode
    exitCode = 1

  console.error args...  unless program.quiet
  process.exit exitCode

program
.version(require('../package').version)
.option('-q, --quiet', 'quiet mode')
.option('-v, --verbose', 'verbose mode')
.option('-p, --patch', 'bump patch version [default]')
.option('-m, --minor', 'bump minor version')
.option('-M, --major', 'bump major version')
.option('-t, --to <version>', 'explicit version to bump to')
.option('-b, --bump [name]', 'package property to bump: [version]', 'version')
.option('-d, --dependency [package]', 'what (dev?)dependency to bump')
.option('-l, --latest', 'for a package dependency, bump to latest version')
.option('-B, --beta',   'for a package dependency, bump to latest beta')
.option('-f, --force', 'proceeds even if the given version is a bump backwards')
.option('-n, --no-edit', 'do not actually write package.json; just simulate it')
.parse(process.argv)

DIST_TAGS = ['latest', 'beta']
newVersion = 'latest'  if program.latest
newVersion = 'beta'    if program.beta
newVersion or= ver = program.to
fail "Not a SemVer-legal version:", ver  if ver and !semver.valid ver

# backwards compat and Do-What-I-Mean: have first the arg also work for version
argDWIM = program.args.shift()
if semver.valid argDWIM
  newVersion or= argDWIM
  argDWIM = program.args.shift()

dependencyVersion = (name) ->
  version = pkg.dependencies[name] or pkg.devDependencies[name]
  fail 'package.json has no dependency or devDependency:', name  unless version?

  return valid  if valid = semver.valid version
  return valid  if valid = semver.valid version.split('#v')[1] # tagged git urls

  fail "Failed to decode old version number from: #{version}"  unless newVersion

oldVersion = pkg[program.bump]
oldVersion = dependencyVersion dep  if dep = program.dependency
# slight amount of DWIM and convenience: undeclared arg also works for packages
oldVersion = dependencyVersion dep  if !dep and (dep = argDWIM)

target = -> dep or "package.json:#{program.bump}"
setVer = (newVersion) ->
  me = target()
  if !program.force and semver.lt newVersion, oldVersion
    fail 3, "Use --force to downgrade #{me} from #{oldVersion} to #{newVersion}"
  log me, oldVersion, '=>', newVersion

  return pkg[program.bump] = newVersion  unless dep?
  return pkg.dependencies[dep] = newVersion  if pkg.dependencies[dep]
  return pkg.devDependencies[dep] = newVersion  if pkg.devDependencies[dep]
  fail "No such package.json dependency:", dep

packageUrl = (name) ->
  repo = pkg.publishConfig?.registry ? 'https://registry.npmjs.org'
  repo += '/'  unless repo.slice(-1) is '/'
  repo + name

fetchPackageVer = (name, channel, cb) ->
  url = packageUrl name
  request { url, json: true }, (err, res) ->
    fail "#{ url }: missing response body"  if err? or !res?.body

    tags = res.body['dist-tags']
    if version = tags?[channel]
      cb version
    else
      fail "Package '#{dep}' has no '#{channel}' dist-tag:", tags

getVersion = (done) ->
  bump = 'patch'  if program.patch
  bump = 'minor'  if program.minor
  bump = 'major'  if program.major
  newVersion or= 'latest'  if dep and !bump # a saner package dependency default

  if newVersion
    if newVersion in DIST_TAGS
      fail "Please state --dependency <package> for --#{newVersion}"  unless dep
      return fetchPackageVer dep, newVersion, done
    else
      return done newVersion

  done semver.inc oldVersion, bump or 'patch'

if !oldVersion and !newVersion
  fail "package.json:#{program.bump} property unset, and no --to version given!"

# try to detect the package.json format and attempt to reproduce the same format
# (including maintaining newline sections where they were before, if simplistic)
json = (x) ->
  matchLine = (property, newlines = '') ->
    ///
      ([ \x20 \[\{, ]*
      "#{ property }"
      : [^\n]*
        [ \s \] \} , ]*
        [^\n]
      )
      ( \n#{newlines} )
    ///gm

  # diff-friendlier comma-first json, or node standard?
  stringify = if raw.slice(0, 3) is '{ "' then format.diffy else format.plain

  # white-space-maintaining JSON formatter
  res = stringify x
  res += '\n'  if raw.slice(-1) is '\n' # first add back the trailing newline

  linePlusBreak = matchLine '([^"\\n]*)', '{2,}'
  while match = linePlusBreak.exec raw
    [all, line, property, newlines] = match
    res = res.replace matchLine(property), '$1' + newlines

  res

getVersion (newVersion) ->
  process.exit 2  if oldVersion is newVersion # signals no-op (to shell scripts)
  setVer newVersion
  fs.writeFileSync 'package.json', json pkg  unless program.noEdit
  process.exit 0 # signals successful actual change for shell scripts
