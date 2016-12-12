# installer

Installer script for Intecture components that powers https://get.intecture.io.

```
Usage: get.sh [-u -y] [-d <path>] (agent | api | auth | cli)

Flags:
    -d <path>   Specify the path to use as a work directory
    -u          Uninstall component instead of installing it
    -y          Answer "yes" to prompts
```

For example, to install the API without prompts, you would run:

```
$ curl -sSf https://get.intecture.io/ | sh -s -- -y api
```

To uninstall it, just pass the `-u` flag:

```
$ curl -sSf https://get.intecture.io/ | sh -s -- -u api
```

If you want to cache an Intecture package locally, you must specify a work directory to use, which will not be cleaned up after installation:

```
$ curl -sSf https://get.intecture.io/ | sh -s -- -d /var/cache/incli cli
```
