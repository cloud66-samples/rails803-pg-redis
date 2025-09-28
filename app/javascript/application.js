// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

document.addEventListener('turbo:load', () => {
  const flowerRows = document.querySelectorAll('.flower-row');
  flowerRows.forEach(row => {
    row.addEventListener('click', () => {
      window.location.href = row.dataset.href;
    });
  });
});
