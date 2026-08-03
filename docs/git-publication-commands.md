# Future Git publication review

The repository is already initialized on `main` and already contains the initial public beta commit. Do not repeat repository initialization or recreate that commit.

## Read-only verification

Before any later publication decision, the maintainer can inspect the repository without changing it:

```powershell
git status --short
git diff --stat
git diff --cached --name-only
git remote -v
git tag --list
git log -1 --oneline --decorate
```

Review `docs/public-file-manifest.txt` against every intentional future public change. Generated reports, private runtime evidence, local-only audit evidence, and the two unpublished legacy executables are not public manifest entries. Four approved audit summaries are public; the remaining eight audit artifacts stay local.

## Author-email privacy decision

A public commit exposes its recorded author metadata. Before publication, the maintainer must decide whether the existing commit-author address is suitable for public exposure. Do not print or change Git identity configuration as part of an automated review.

## Future explicit changes

Only after the maintainer reviews the ordinary working-tree diff should they decide which exact paths, if any, belong in a future commit. Staging and committing require separate manual approval. Avoid broad staging; compare each approved path with the public manifest and inspect the staged diff before committing.

## Later GitHub steps

Repository creation, remote configuration, tags, and any push are separate external actions. Perform them only after explicit approval of visibility, private security reporting, author-email privacy, the final file set, and the complete staged diff. This guide intentionally provides no automatic remote, tag, or push command.
