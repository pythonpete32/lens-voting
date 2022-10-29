# Lens Voting

> AragonV2 voting plugin compatible with lens FollowNFT

## Development

### Build & test

[Install Foundry](https://book.getfoundry.sh/getting-started/installation.html), (assuming a Linux or macOS system):

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Install dependencies, build, and run tests with coverage:

```bash
make
```

Generate code coverage HTML report:

```
forge coverage --report lcov
brew install lcov
genhtml lcov.info -o coverage
```

Then open coverage/index.html in a browser.

### Linters

Install dependencies:

```
yarn install
```

Run linter checks:

```
yarn lint:check
```

Automatic linter fix:

```
yarn lint:fix
```
