<p style="float:right">
  <img alt=Screenshot src=pristine-white-canvas.png>
</p>

This is the source code for a Julia web server that allows users to collaboratively draw on a single 500×500 image.

Deployed on [Heroku](https://image-modifier-project.herokuapp.com/).

Conclusion from developing this, and trying to deploy it: Julia is (still) poorly-suited for web servers.

---

# How to run this

This assumes that you have cloned this repository locally.

### Locally

Assuming that you have [Docker](https://docs.docker.com/get-docker/) installed and a [PostgreSQL](https://www.postgresql.org/docs/) server running, build it with:

```bash
docker build -t image-modifier-project .
```

and run with something like

```bash
docker run -p 8089:80 -e PORT=80 -e DATABASE_URL=... image-modifier-project
```

The Docker image is only 500MB, how can you possibly have trouble with Heroku's 500MB RAM limit.

### Deploying to Heroku

[Create a Heroku app](https://devcenter.heroku.com/articles/creating-apps), and:

```bash
heroku stack:set container
heroku container:login
heroku container:push web && heroku container:release web
```

Alternatively, [deploy with Git](https://devcenter.heroku.com/articles/git).

Alternatively, to push from a Git repo:

```bash
heroku stack:set container
git push heroku master
```