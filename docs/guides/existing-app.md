# Bringing an existing app to Lighthouse

A greenfield repo with a Dockerfile usually deploys on the first click. An app that has lived
for years, with its own dev scripts, a database you care about and migrations spread over
several folders, needs a few decisions first. This guide walks through them in the order you
meet them in the UI, and says plainly where Lighthouse still falls short.

It was written from a real migration: a Laravel 13 / PHP 8.3 monolith with MySQL, Redis,
Memcached, a gulp front end, a 200 MB production-style dump and about 800 migrations.

## 1. Before you start: check the repo

Answer these from the repo itself, not from your laptop. Lighthouse builds from a fresh clone,
so anything gitignored does not exist for it.

| Question | Why it matters |
|---|---|
| Is there a `Dockerfile` or `compose.yml` / `docker-compose.yml` **committed** at the root? | That decides the build method. Generated compose files (written by a dev script) are invisible to a fresh clone. |
| Is the compose file a **dev** setup? | Bind mounts of the source (`.:/var/www`), xdebug, published host ports and `container_name` are dev patterns. Lighthouse strips published ports, but a source bind mount means the image has no code in it. |
| Which runtime versions does it need? | e.g. `"php": "^8.3"` in `composer.json`, `engines` in `package.json`. |
| Are build outputs (vendor/, node_modules, compiled CSS/JS) committed? | Usually not, so the build has to produce them. |
| Where does the data come from? | A dump, migrations + seeders, or nothing. See [section 5](#5-data-bring-a-database-in). |

## 2. Create the project

**Projects → New project**

- **Repository URL**
  - **GitHub:** connect GitHub first under **Integrations**. For an organization, an admin adds
    the org's credential; members' deploys use the org credential, never a member's personal
    token. A project in your personal org can use your own connection.
  - **Any other git server** (GitLab, Gitea, self-hosted) over `http(s)` works too, with fewer
    features: no branch list, no merge builds, no push webhooks. You type the branch name.
- **Default branch:** fill it in if the repo's default is not `main` (for example `develop`).
  It is required for non-GitHub repos, because Lighthouse cannot look it up.

A `production` environment is created with the project.

## 3. Choose how it builds

**Project → Settings → Build settings → Build method**

| Method | Pick it when |
|---|---|
| **Auto-detect** | You are not sure. Order: compose file, then Dockerfile, then a generated Dockerfile. |
| **Dockerfile** | The repo has a production Dockerfile. Best option when it exists. |
| **Compose** | The repo has a compose file meant for deployment. Set **Compose file path** if it is not at the root. `${VARS}` in it are filled from the environment's variables. |
| **Generated** | No Dockerfile. Lighthouse writes one, version-matched to the project (Laravel, Symfony, Node/Prisma, Django, Rails). |
| **Nixpacks / Railpack / Buildpacks** | Zero-config builders, useful for common stacks. |
| **Prebuilt image** | You already push images to a registry. |

### Generated builds for PHP / Laravel

- **Runtime version:** the small box under *Build & start* (placeholder "runtime version"). Leave
  it empty to use the version `composer.json` asks for, or set e.g. `8.3`.
- **PHP extensions** are installed from what the project declares: every `ext-*` in
  `composer.json` and in the packages of `composer.lock`. Redis and Memcached are added when the
  app's config uses them.
- `composer install` failing **fails the build**, with composer's own message. Fix the cause
  (usually a missing extension or a lock file out of date) rather than looking for a switch.
- The app is served with `php artisan serve` on port 8080. Laravel's `bootstrap/cache` and
  `storage/` folders are created for you.
- If a managed SQL database exists, `DB_*` variables are injected and `php artisan migrate
  --force` runs after every deploy. See [section 6](#6-migrations) for when that is not enough.

### Front-end assets (gulp, webpack, vite)

The generated PHP image has no Node. Build assets in a **Setup step**, which runs after clone and
before the build, in any image you choose, with the checkout mounted at `/app`:

| Image | Command |
|---|---|
| `node:16` (match the version the project needs) | `npm ci && npx gulp build` |

Whatever the step writes into the checkout is copied into the image.

## 4. Environment variables

**Environment → Env vars → Paste .env** takes a whole `.env` file. Values are write-only after
saving. Changes reach the app on the **next deploy**; terminal sessions and Maintenance actions
run in the current container and do not see them until then.

Start from the app's real `.env` (merge), not a minimal list: older apps read many settings of
their own, and a missing one often surfaces as a crash far from where it is used.

- Do **not** set `DB_HOST`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`: Lighthouse injects them
  from the managed database.
- Set a permanent `APP_KEY` (Laravel). Without one, Lighthouse generates a temporary key per
  deploy and every session and encrypted value breaks on redeploy.
- Set `APP_URL` to the environment's URL. Frameworks build cookies and links from it, and some
  migrations crash without it. Look for the app's **own** host settings too (e.g. `ROOT_HOST`,
  `SITE_URL`): `grep -rn "env('.*HOST\|env('.*URL" config/` finds them. Point every one at the
  environment's URL, never at the hostnames of your local dev containers.
- Point services you do not run yet at something harmless: `CACHE_STORE=file`,
  `SESSION_DRIVER=file`, `QUEUE_CONNECTION=sync`.

## 5. Data: bring a database in

**Environment → Add database**, pick the engine and version, then:

| You have | Do this |
|---|---|
| A dump (`.sql`, `.sql.gz`, Postgres `.dump`) | Open the database and use **Import dump**. It replaces all data in that database, then shows Uploading → Restoring → Imported or Failed with the engine's error. MySQL imports run with strict mode relaxed and foreign key checks off, so dumps from older MySQL versions load. |
| Migrations + seeders that build a usable database | Create it empty with **Run migrations after provisioning**, and set **Migrate command** in Build settings. |
| Another Lighthouse database | Postgres only: **Copy**, or create from a **snapshot**. |

**Use a recent dump.** A dump is only useful if the code's migrations can bring it forward. An
old dump plus new code is the most common way to end up with a site that deploys green and
returns 500 on every page (next section).

Take a **snapshot** right after a good import and mark it as the **baseline**: **Reset
environment** then returns to exactly that state.

## 6. Migrations

After each deploy Lighthouse runs `php artisan migrate --force` (Laravel). Check that it is the
right command for your app:

- **Migrations in subfolders** are not loaded by plain `artisan migrate`. Projects that archive
  old migrations into folders (e.g. `database/migrations/5.8/`) need those applied with
  `--path=...`, and a dump older than the archiving will be missing them.
- **Migrations that need runtime services or env** (S3, mail, `APP_URL`) can fail on a test
  environment.

Run migrations by hand from the UI:

- **Terminal:** the terminal button on a running service on the deployment page. Good for
  `php artisan migrate:status` and `php artisan migrate --pretend` before doing anything real.
- **Maintenance actions:** in **Build settings → Maintenance actions**, add a label, the service
  (`web` for generated builds) and a command, e.g. `php artisan migrate --force`. Each becomes a
  button on the deployment page with live output and the exit code.

## 7. When a deploy fails

The deployment page names the failure and suggests a fix; the raw error is under **Details**.

| You see | It usually means |
|---|---|
| **Build failed** with composer / npm output | The image could not be built. Read the first error in the build log, not the last. |
| **The app crashed on start** + a log line | The container exited before answering. The log line is usually the real error (missing `vendor/`, bad env, missing extension). Open **Runtime logs** for more. |
| **The app never answered on port N** | The app is running but not listening on that port, or boots too slowly. Check the start command listens on `0.0.0.0:$PORT`. |
| Deploy green, site shows a 500 | Usually data vs code: missing columns or tables. See [section 6](#6-migrations). |
| Compose include / env_file errors | The compose file reaches outside the repo. A project deploys one repository. |

## 8. Known gaps (being worked on)

Honest list of what still needs a workaround today:

- **The deploy-time migrate command is fixed** to `php artisan migrate --force` for Laravel; you
  cannot add `--path` folders. Use a Maintenance action meanwhile.
- **A failed deploy-time migration does not fail or flag the deploy.** It is only in the build
  log, so a deploy can be green while the app errors.
- **MySQL dumps with triggers, stored routines or `DEFINER=` clauses** fail to import, because
  the managed database user is not root. Strip definers or export without routines for now.
- **Non-GitHub repos** get no branch list, merge builds or push webhooks.
- **GitHub onboarding for organizations** (org credential, repo browser, private clone) has not
  been run end to end yet; report anything odd.
- **Large uploads in production** (dump import) need the reverse proxy's read timeout raised;
  the default cuts requests off after 60 seconds.
- **Generated PHP images have no Node**; build front-end assets in a Setup step (section 3).

## Checklist

1. Repo has a committed, production-shaped Dockerfile or compose file, or you accept a generated
   build.
2. Project created with the right **default branch**.
3. Build method chosen; runtime version set if needed; Setup step for assets if needed.
4. Env vars pasted from the app's real `.env`, with `APP_KEY`, `APP_URL` and the app's own host
   settings pointed at the environment; no `DB_*`. Redeploy after changing them.
5. Database added and filled: **Import dump** from a *recent* dump, then snapshot it as baseline.
6. Deploy. If it is green but erroring, check migrations first.
