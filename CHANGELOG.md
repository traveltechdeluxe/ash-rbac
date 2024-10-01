# AshRbac

All notable changes to this project will be documented here. The format is based
on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project
adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## 2024-10-01 0.6.1

### Fixes

- adapt to changes introduced in the latest `ash` version

## 2024-06-03 0.6.0

### Features

- Ash 3.0 support

## 2024-04-05 0.5.0

### Features

- allow adding custom conditions to fields

## 2023-09-19 0.4.0

### Features

- add support for a list of conditions for actions

### Fixes

- move role check into policy condition to make multiple roles with similar conditions work

## 2023-08-08 0.3.2

### Fixes

- make sure transform is run after relationship attributes are set
- make sure transform is run before the authorizer add-missing-fields transform

## 2023-07-28 0.3.1

### Fixes

- only add default forbid policy to fields that do not have a (custom) policy yet

## 2023-07-26 0.3.0

### Features

- auto import builtin policy checks and template helpers

### Fixes

- handle actor = nil in role check

## 2023-07-24 0.2.1

### Fixes

- make sure HasRole describe function can handle a single role as well as a list of roles

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
