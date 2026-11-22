// Counts down the time left to pay, and returns to the cart once it's over.
// The server sends the seconds left instead of an end time, such that neither
// date parsing nor a wrong clock on the user's device can break the countdown.
let setupCountdownTimer = function() {
  let countdownElement = document.querySelector('.countdown');
  let timerElement = document.getElementById('time-left');
  if (!countdownElement || !timerElement) return;

  let secondsLeftOnLoad = parseInt(countdownElement.dataset.secondsLeft, 10);
  let redirectPath = countdownElement.dataset.redirect;
  if (Number.isNaN(secondsLeftOnLoad)) return;

  let endTime = Date.now() + secondsLeftOnLoad * 1000;
  let interval = null;

  let update = function() {
    let secondsLeft = Math.ceil((endTime - Date.now()) / 1000);

    if (secondsLeft <= 0) {
      clearInterval(interval);
      timerElement.textContent = '0:00';
      window.location.replace(redirectPath);
      return;
    }

    let minutes = Math.floor(secondsLeft / 60);
    let seconds = secondsLeft % 60;
    timerElement.textContent = `${minutes}:${String(seconds).padStart(2, '0')}`;
  };

  update();
  interval = setInterval(update, 1000);
};
