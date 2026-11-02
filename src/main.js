import { Game } from './game.js';

const canvas = document.getElementById('game');
try {
  const game = new Game(canvas);
  window.__wh = game.testHook ? game.testHook() : { game };
  document.getElementById('boot-msg').remove();
  game.start();
} catch (err) {
  console.error(err);
  document.getElementById('boot-msg').textContent = 'Wonderhaven could not start: ' + err.message;
}
