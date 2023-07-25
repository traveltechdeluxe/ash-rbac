# AshRbac

All notable changes to this project will be documented here. The format is based
on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project
adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## Unreleased

### Fixes

- handle actor = nil in role check

## 2023-07-24 0.2.1

### Fixes

- make sure HasRole describe function can handle as single role as well as a list of roles

## 2023-07-24 0.2.0

### Features

- add support for actors with different roles attribute

## 2023-07-19 0.1.1

### Fixes

- refactor code to create a lot fewer policies in order to improve performance
- add source links to package info

## 2023-07-17 0.1.0

### Features

- support string roles
- support list of roles

### Fixes

- fix `:*` field policies
- do not add empty field-policies
- refactor checks to work better with other ash policies

## 2023-07-13 0.0.1

### Features

- initial release
