# qbasic-snuggle-os

A QBasic project I did in 1999: Snuggle OS, a desktop with draggable,
mouse-driven windows, written in QBasic. It still runs today, in DOSBox in the browser, packaged in a container and
hosted on Google Cloud Run.

Live at https://snuggleos-vtmxwzy3uq-lz.a.run.app

## When

The QBasic program (`SNUGGLE.BAS`) is from 1999. The container, Terraform and
GitHub Actions setup that deploys it were added in 2020.

## How it works

- `SNUGGLE.BAS` is the original program.
- `qb11.zip` holds QBasic 1.1. The `Dockerfile` adds `SNUGGLE.BAS` and
  `dosbox.conf` to it and builds a js-dos web app with `create-dosbox`.
- `.github/workflows/build-and-deploy.yml` builds the image on every push to
  `master` and deploys it to Cloud Run with the Terraform in `terraform/`.

## Run locally

```sh
docker build -t snuggle-os .
docker run --rm -p 8080:8080 snuggle-os
```

Then open http://localhost:8080.

## Status

Done. Kept running as a piece of nostalgia.

## License

0BSD, see [LICENSE](LICENSE). It does not cover QBasic 1.1 in `qb11.zip`
(Microsoft), the Vmouse routine by Mark K. Kim in `SNUGGLE.BAS`, or the
Apache-2.0 deploy workflow from Google.
