/// Converts Flutter [ReorderableListView.onReorder] indices to insert-at
/// positions after the item has been removed.
int adjustedReorderIndex(int oldIndex, int newIndex) {
  return newIndex > oldIndex ? newIndex - 1 : newIndex;
}
