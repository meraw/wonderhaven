// Kingdom Harmony milestones: what each level unlocks.
export const HARMONY_UNLOCKS = [
  { at: 15, id: 'cozy', title: 'Cozy Corners', desc: 'New blueprints: Pillar, Stairs and Raised Platform.', blueprints: ['pillar', 'stairs', 'platform'] },
  { at: 50, id: 'plot', title: 'A Bigger Garden', desc: 'Your garden plot grows, and you can build Foundations and Roofs.', blueprints: ['foundation', 'roof'] },
  { at: 80, id: 'lights', title: 'Sparkling Lights', desc: 'New blueprints: Streetlight and Windmill.', blueprints: ['streetlight', 'windmill'] },
  { at: 120, id: 'harbor', title: 'Harbor Charter', desc: 'Lord Percival can lift the decree sealing the harbor.' },
  { at: 160, id: 'trail', title: 'Starlight Steps', desc: 'Your footsteps leave a trail of sparkles.' },
  { at: 200, id: 'crown', title: 'Royal Recognition', desc: 'The Royal Crown outfit.', clothes: ['crown'] },
  { at: 250, id: 'virtuoso', title: 'Starforge Virtuoso', desc: 'Every blueprint in Hearthglow is yours.', allBlueprints: true },
];
// Small Harmony rewards for good deeds outside quests.
export const HARMONY_DEEDS = { firstPieceType: 1, friendHeart: 1 };
export function nextUnlock(harmony) { return HARMONY_UNLOCKS.find(u => u.at > harmony) || null; }
export function unlocksBetween(before, after) { return HARMONY_UNLOCKS.filter(u => u.at > before && u.at <= after); }
