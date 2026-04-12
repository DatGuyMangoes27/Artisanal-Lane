const Duration curatedCollectionResumeDelay = Duration(seconds: 3);
const Duration curatedCollectionTick = Duration(milliseconds: 40);
const double curatedCollectionScrollStep = 0.8;

bool shouldAutoScrollCuratedCollection(int itemCount) {
  return itemCount > 1;
}
