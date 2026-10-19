# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/2.0.0/).

## [Unreleased]

## 2026-10-18

### Added

- The map page now shows an embed of the subway diagram.

### Changed

- On desktop, there is now a maximum width. This prevents the pages from looking
  very stretched on wide screens.

## 2026-10-12

### Added

- When clicking between stops and trains, a log of transfers will be created at
  the top of the screen.

## 2026-10-02

### Changed

- The stop current being displayed is highlighted in the transfers list.

## 2026-09-13

### Changed

- There is now more information on the index page, and it now points to the
  Tangled repo instead of the GitHub one.
- All pages should load very slightly faster (3–5ms or so in the median, but
  30–80ms on the high end). It's just barely noticable if they're side by side.
  Enjoy :]

## 2026-06-16

### Changed

- The direction labels are now customized per station, instead of always saying
  "Uptown" or "Downtown".

  For example, when viewing Jackson Hts-Roosevelt Av on the Queens Boulevard
  Line, the two directions will be "Outbound" and "Manhattan".

## 2026-06-15

### Fixed

- The routes shown for a given station will be only the ones that stop during
  normal daytime service. Routes that only stop at a station during rush hour or
  during late nights will not be listed.

  For example, the local stops on the Lexington Av Line will be correctly shown
  as having the 6 stop there, instead of both the 6 and the 4. (The 4 runs local
  in Manhattan late nights.)
