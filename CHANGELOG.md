## 0.0.16

- chore: revert back to riverpod 2

## 0.0.15

- fix: cover continue path resolution for sequential Guard1→Guard2 flow in nested and flattened shield

## 0.0.14

- fix: properly evaluate every enclosing guard even if destination is shield of a passing guard

## 0.0.13

- fix: improve path sanitization
- feat: support custom log callback

## 0.0.12

- fix: expose pathAliases on RouteId constructor

## 0.0.11

- feat: support `pathAliases`, "synthetic" routes which gets redirected to canonical path

## 0.0.10

- Require 
### Breaking Changes
- **BREAKING**: Upgraded to Riverpod 3.0.3
- **BREAKING**: `GoNotifier.dependencies` now accepts `List<ProviderListenable<Object?>>` instead of `List<AlwaysAliveProviderListenable<Object>>`

## 0.0.9

- fix: an assertion error when redirecting to a route without current pathParam

## 0.0.8

- fix: remove an unecessary exception throwing when DiscardShell had a non-GoRoute as direct child

## 0.0.7

- fix: resolve guards in treePath in order of appearance instead of definition

## 0.0.6

- feat: support path parameters
- chore: bump go_router to ^14.0.0

## 0.0.5

- feat: `DestinationPersistence`

## 0.0.4

- chore: update Flutter version to 3.19.2
- feat: add `clearsContinue` to `GuardShell`

## 0.0.3

- fix: make guard redirects have higher precedence than explicit redirects

## 0.0.2

- fix: remove `DeepLinkHandler` and `uni_links` package

## 0.0.1

Initial release.
