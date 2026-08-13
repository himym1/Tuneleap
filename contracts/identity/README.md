# Weak song identity

`weak_identity` is a stable string used to treat two recordings as the same work for recommendation blocking and duplicate import.

Expected shape:

```text
{canonical_title}\u001f{canonical_artist}
```

Flutter may encode multiple artist tokens joined by `\u001e` after sorting. Python currently uses a single primary-artist string. Cases marked `"expect": "equal"` must match within one implementation and, after the drift is closed, across all three.

See [`cases.v1.json`](cases.v1.json).
