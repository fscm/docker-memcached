# Memcached for Docker

A small Memcached image that can be used to start a Memcached server.

## Supported tags

- [`latest`](https://github.com/fscm/docker-memcached/blob/master/Dockerfile)

## What is Memcached?

> Memcached is an in-memory key-value store for small chunks of arbitrary data (strings, objects) from results of database calls, API calls, or page rendering.

*from* [memcached.org](https://memcached.org/)

## Getting Started

There are a couple of things needed for the script to work.

### Prerequisites

Docker, either the Community Edition (CE) or Enterprise Edition (EE), needs to
be installed on your local computer.

#### Docker

Docker installation instructions can be found
[here](https://docs.docker.com/install/).

### Usage

To start a container with this image use the following command:

```shell
docker container run --rm --interactive --tty fscm/memcached [memcached_options]
```

To view a list of all of the available options use the following command:

```shell
docker container run --rm --interactive --tty fscm/memcached --help
```

#### Starting a Memcached Server

The quickest way to start a Memcached server is with the following command:

```shell
docker container run --detach --publish 11211:11211/tcp --name my_memcached fscm/memcached
```

To run the Memcached server as a `non-root` user use the `--user` option from
Docker, like so:

```shell
docker container run --user $(id -u):$(id -g) --detach --publish 11211:11211/tcp --name my_memcached fscm/memcached
```

#### Stop the Memcached Server

If needed the Memcached server can be stopped and later started again (as long
as the command used to perform the initial start did not included the `--rm`
option).

To stop the server use the following command:

```shell
docker container stop CONTAINER_ID
```

To start the server again use the following command:

```shell
docker container start CONTAINER_ID
```

## Build

Build instructions can be found
[here](https://github.com/fscm/docker-memcached/blob/master/README.build.md).

## Versioning

This project uses [SemVer](http://semver.org/) for versioning. For the versions
available, see the [tags on this repository](https://github.com/fscm/docker-memcached/tags).

## Authors

- **Frederico Martins** - [fscm](https://github.com/fscm)

See also the list of [contributors](https://github.com/fscm/docker-memcached/contributors)
who participated in this project.
