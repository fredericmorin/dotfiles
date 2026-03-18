# New Computer Setup

## pyenv

```sh
brew install pyenv
pyenv install 3.12
pyenv global 3.12
git clone https://github.com/pyenv/pyenv-pip-rehash.git $(pyenv root)/plugins/pyenv-pip-rehash  # auto-rehash shims after pip install/uninstall
```
