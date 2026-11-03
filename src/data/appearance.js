// Character customisation options. `locked` items unlock through quests, friendship and exploration (see outfits.js).
export const SKIN_TONES = ['#ffe3cc', '#f8cfa8', '#e9b083', '#c98a5e', '#9a6442', '#6b4330'];
export const EYE_SHAPES = ['round', 'sparkle', 'happy', 'sleepy', 'wide'];
export const EYE_COLORS = ['#3a2a1e', '#2f6fdf', '#3c9a4a', '#8a4fd8', '#d9822b', '#c23f6a'];
export const HAIR_STYLES = ['short', 'bob', 'pigtails', 'bun', 'long', 'spiky', 'curly', 'ponytail'];
export const HAIR_COLORS = ['#3b2a20', '#7a4a2a', '#d9a35a', '#f3d77a', '#e86f5c', '#ff9ec7', '#7aa8ff', '#9a7ad6', '#f2f2f2', '#55c49a'];
export const MOUTHS = ['smile', 'grin', 'cat', 'calm', 'o'];
export const TOPS = ['tee', 'sweater', 'tunic', 'jacket', 'sailor', 'overalls'];
export const BOTTOMS = ['pants', 'shorts', 'skirt', 'dress'];
export const SHOES = ['sneakers', 'boots', 'sandals'];
export const HATS = ['none', 'beret', 'beanie', 'bow', 'sunhat', 'chef', 'flowerCrown', 'captain', 'crown', 'goggles'];
export const ACCESSORIES = ['none', 'glasses', 'scarf', 'backpack', 'bowtie', 'beard'];
export const CLOTH_COLORS = ['#ff8fab', '#ffd166', '#7bd389', '#6cc4ff', '#b59cff', '#ff9f5a', '#ffffff', '#4a4a6a', '#e85d75', '#3fb5a3', '#c9a27a', '#2f5fa8'];

export const LABELS = {
  round: 'Round', sparkle: 'Sparkly', happy: 'Cheerful', sleepy: 'Dreamy', wide: 'Wide-eyed',
  short: 'Short crop', bob: 'Bob', pigtails: 'Pigtails', bun: 'Top bun', long: 'Long', spiky: 'Spiky', curly: 'Curly', ponytail: 'Ponytail',
  smile: 'Smile', grin: 'Big grin', cat: 'Cat smile', calm: 'Calm', o: 'Oh!',
  tee: 'T-shirt', sweater: 'Sweater', tunic: 'Tunic', jacket: 'Jacket', sailor: 'Sailor top', overalls: 'Overalls',
  pants: 'Trousers', shorts: 'Shorts', skirt: 'Skirt', dress: 'Dress',
  sneakers: 'Sneakers', boots: 'Boots', sandals: 'Sandals',
  none: 'None', beret: 'Beret', beanie: 'Beanie', bow: 'Bow', sunhat: 'Sun hat', chef: 'Chef hat', flowerCrown: 'Flower crown', captain: 'Captain hat', crown: 'Royal crown', goggles: 'Inventor goggles',
  glasses: 'Glasses', scarf: 'Scarf', backpack: 'Backpack', bowtie: 'Bow tie', beard: 'Beard',
};

export const DEFAULT_APPEARANCE = {
  // a traveller just off the coast road: jacket, scarf and walking boots
  skin: SKIN_TONES[1], eyeShape: 'round', eyeColor: EYE_COLORS[0], hair: 'bob', hairColor: HAIR_COLORS[1], mouth: 'smile',
  top: 'jacket', topColor: '#3fb5a3', bottom: 'pants', bottomColor: '#4a4a6a', shoes: 'boots', shoesColor: '#c9a27a',
  hat: 'none', hatColor: '#ffd166', accessory: 'scarf',
};

// The pieces of clothing that start locked, and how they unlock.
export const LOCKED_CLOTHES = {
  overalls: "Help Bram furnish his workshop",
  sunhat: "Become good friends with Fern",
  flowerCrown: "Find the chest hidden in the orchard",
  goggles: "Restore the garden fountain with Tilly",
  chef: "Shoo the squirrels out of Mabel's bakery",
  captain: "Earn the Captain's trust by catching fish",
  crown: "Reach 200 Kingdom Harmony",
  sailor: "Open the harbor",
  backpack: "Find three hidden treasures",
};

export function sanitizeAppearance(a = {}) {
  const pick = (v, list, d) => (list.includes(v) ? v : d);
  const color = (v, d) => (typeof v === 'string' && /^#[0-9a-f]{6}$/i.test(v) ? v : d);
  const D = DEFAULT_APPEARANCE;
  return {
    skin: color(a.skin, D.skin), eyeShape: pick(a.eyeShape, EYE_SHAPES, D.eyeShape), eyeColor: color(a.eyeColor, D.eyeColor),
    hair: pick(a.hair, HAIR_STYLES, D.hair), hairColor: color(a.hairColor, D.hairColor), mouth: pick(a.mouth, MOUTHS, D.mouth),
    top: pick(a.top, TOPS, D.top), topColor: color(a.topColor, D.topColor), bottom: pick(a.bottom, BOTTOMS, D.bottom), bottomColor: color(a.bottomColor, D.bottomColor),
    shoes: pick(a.shoes, SHOES, D.shoes), shoesColor: color(a.shoesColor, D.shoesColor), hat: pick(a.hat, HATS, D.hat), hatColor: color(a.hatColor, D.hatColor),
    accessory: pick(a.accessory, ACCESSORIES, D.accessory),
  };
}
