# Contributing

Thank you for helping keep this project small and trustworthy.

1. Discuss large features before implementing them.
2. Keep chat processing local. New networking code requires an explicit design
   discussion and a clearly visible user-facing reason.
3. Add tests for parsing, storage or cleanup behavior.
4. Run `swift test` and `Scripts/make-app.sh` before opening a pull request.
5. Do not commit signing certificates, provisioning profiles, tokens or local
   App Group credentials.

Bug reports should include the macOS and WeChat versions, what was shared, and
the observed result. Remove names, messages and file paths from logs first.
