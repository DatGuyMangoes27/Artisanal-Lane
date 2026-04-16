const Duration curatedCollectionResumeDelay = Duration(seconds: 3);
const Duration curatedCollectionTick = Duration(milliseconds: 16);
const double curatedCollectionScrollStep = 1.8;

bool shouldAutoScrollCuratedCollection(int itemCount) {
  return itemCount > 1;
}
