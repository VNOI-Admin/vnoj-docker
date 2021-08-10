# VNOJ Docker

This repository contains the Docker files to run the [VNOJ](https://github.com/VNOI-Admin/OJ). It configures some additional services, such as [Mathoid](https://github.com/wikimedia/mathoid) and [Texoid](https://github.com/DMOJ/texoid).

## Installation

First, [Docker](https://www.docker.com/) and [Docker Compose](https://docs.docker.com/compose/) must be installed. Installation instructions can be found on their respective websites.

Clone the repository:

```sh
$ git clone https://github.com/VNOI-Admin/vnoj-docker
$ cd vnoj-docker
$ git submodule update --init --recursive
$ cd dmoj
```

From now on, it is assumed you are in the `dmoj` directory.

Initialize the setup by moving the configuration files into the submodule and creating the necessary directories:

```sh
$ ./scripts/initialize
```

Configure the environment variables in the files in `dmoj/environment/`. In particular, set the MYSQL passwords in `mysql.env` and `mysql-admin.env`, and the host and secret key in `site.env`. Also, configure the `server_name` directive in `dmoj/nginx/conf.d/nginx.conf`.

Next, build the images:

```sh
$ docker-compose build
```

Or you can just pull them from Docker Hub:

```sh
$ docker-compose pull
```

Start up the site, so you can perform the initial migrations and generate the static files:

```sh
$ docker-compose up -d site
```

You will need to generate the schema for the database, since it is currently empty:

```sh
$ ./scripts/migrate
```

You will also need to generate the static files:

```
$ ./scripts/copy_static
```

Finally, the DMOJ comes with fixtures so that the initial install is not blank. They can be loaded with the following commands:

```sh
$ ./scripts/manage.py loaddata navbar
$ ./scripts/manage.py loaddata language_small
$ ./scripts/manage.py loaddata demo
```

## Usage

```
$ docker-compose up -d
```

## Notes

### Migrating

As the DMOJ site is a Django app, you may need to migrate whenever you update. Assuming the site container is running, running the following command should suffice:

```sh
$ ./scripts/migrate
```

### Managing Static Files

If your static files ever change, you will need to rebuild them:

```
$ ./scripts/copy_static
```

### Updating The Site

Updating various sections of the site requires different images to be rebuilt.

If any prerequisites were modified, you will need to rebuild most of the images:

```sh
$ docker-compose up -d --build base site celery bridged wsevent
```

If the static files are modified, read the section on [Managing Static Files](#managing-static-files).

If only the source code is modified, a restart is sufficient:

```sh
$ docker-compose restart site celery bridged wsevent
```

### Multiple Nginx Instances

The `docker-compose.yml` configures Nginx to publish to port 80. If you have another Nginx instance on your host machine, you may want to change the port and proxy pass instead.

For example, a possible Nginx configuration file on your host machine would be:

```
server {
    listen 80;
    listen [::]:80;

    add_header X-UA-Compatible "IE=Edge,chrome=1";
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    location / {
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_set_header Host $http_host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_pass http://127.0.0.1:10080/;
    }
}
```

In this case, the port that the Nginx instance in the Docker container is published to would need to be modified to `10080`.

### Load balancing

By default, all services (site, bridged, wsevent, db, celery, redis, etc.) run in the same machine. However, it is not ideal for handling a large number of users. In this case, you need to distribute the services to multiple servers. A typical setup would be:

- One central server for nginx, db, redis, bridged, and wsevent
- Multiple workers, each will run site and celery

#### Central server

You need to configure `dmoj/nginx/conf.d/nginx.conf` to distribute traffic to workers. Refer to [Nginx docs](https://docs.nginx.com/nginx/admin-guide/load-balancer/http-load-balancer/) for how to do it.

You also need to open these ports for workers to connect to:

- db: 3306
- redis: 6379
- bridged: 9998 9999
- wsevent: 15100 15101 15102

Now, let's start the services:

```sh
docker-compose up -d nginx db redis bridged wsevent
```

#### Worker

You need to configure `dmoj/environment/site.env` and `dmoj/environment/mysql.env` to point to the central server.

```sh
docker-compose up -d site celery
```
