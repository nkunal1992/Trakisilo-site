// Trakisilo site — view-aware video playback, carousel, mobile nav.
(function () {
  "use strict";

  var reduced = window.matchMedia("(prefers-reduced-motion: reduce)");

  // Videos with data-autoplay play muted/looped only while ≥40% visible.
  var vids = Array.prototype.slice.call(document.querySelectorAll("video[data-autoplay]"));
  function apply() {
    if (reduced.matches) {
      vids.forEach(function (v) {
        v.removeAttribute("autoplay");
        v.pause();
        v.controls = true;
      });
      return;
    }
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        var v = e.target;
        if (e.intersectionRatio >= 0.4) {
          if (v.dataset.src && !v.src) v.src = v.dataset.src;
          v.play().catch(function () {});
        } else {
          v.pause();
        }
      });
    }, { threshold: [0, 0.4] });
    vids.forEach(function (v) { io.observe(v); });
  }
  apply();
  reduced.addEventListener ? reduced.addEventListener("change", apply) : reduced.addListener(apply);

  // Carousel prev/next + arrow keys.
  document.querySelectorAll(".carousel").forEach(function (car) {
    var track = car.querySelector(".car-track");
    var step = function (dir) {
      var fig = track.querySelector("figure");
      var w = fig ? fig.getBoundingClientRect().width + 16 : track.clientWidth * 0.8;
      track.scrollBy({ left: dir * w, behavior: "smooth" });
    };
    var prev = car.querySelector(".car-prev");
    var next = car.querySelector(".car-next");
    if (prev) prev.addEventListener("click", function () { step(-1); });
    if (next) next.addEventListener("click", function () { step(1); });
    track.addEventListener("keydown", function (e) {
      if (e.key === "ArrowLeft") { step(-1); e.preventDefault(); }
      if (e.key === "ArrowRight") { step(1); e.preventDefault(); }
    });
  });

  // Mobile nav.
  var tog = document.querySelector(".nav-toggle");
  if (tog) {
    tog.addEventListener("click", function () {
      document.querySelector(".nav-links").classList.toggle("open");
    });
  }
})();
