# New Computer Setup

## pyenv

```sh
# install
brew install pyenv

# install a python version
pyenv install 3.12

# set global default
pyenv global 3.12

# auto-rehash after pip install/uninstall
git clone https://github.com/pyenv/pyenv-pip-rehash.git $(pyenv root)/plugins/pyenv-pip-rehash
```
