(function () {
  var blocks = Array.prototype.slice.call(
    document.querySelectorAll('pre > code.language-mermaid')
  );
  if (!blocks.length) return;
  var nodes = blocks.map(function (code) {
    var div = document.createElement('div');
    div.className = 'mermaid';
    div.textContent = code.textContent;
    code.parentNode.parentNode.replaceChild(div, code.parentNode);
    return div;
  });
  var s = document.createElement('script');
  s.src = 'https://cdn.jsdelivr.net/npm/mermaid@10.9.1/dist/mermaid.min.js';
  s.onload = function () {
    mermaid.initialize({ startOnLoad: false, theme: 'neutral' });
    mermaid.run({ nodes: nodes });
  };
  document.body.appendChild(s);
})();
