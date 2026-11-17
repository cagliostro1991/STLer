# Wiki sources

These files are the GitHub wiki of the repository (https://github.com/cagliostro1991/STLer/wiki). They live here so changes can be reviewed in pull requests, and are copied to the wiki repository (`STLer.wiki.git`) when they change:

```
git clone git@github.com:cagliostro1991/STLer.wiki.git /tmp/stler-wiki
cp docs/wiki/*.md /tmp/stler-wiki/ && rm /tmp/stler-wiki/README.md
cd /tmp/stler-wiki && git add -A && git commit -m "Sync from docs/wiki" && git push
```

The wiki repository exists only after the first page was created once in the web UI (Wiki tab, "Create the first page").
