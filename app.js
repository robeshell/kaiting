const header = document.querySelector('[data-header]');
const nav = document.querySelector('[data-nav]');
const navToggle = document.querySelector('[data-nav-toggle]');

const updateHeader = () => {
  header?.classList.toggle('scrolled', window.scrollY > 20);
};

updateHeader();
window.addEventListener('scroll', updateHeader, { passive: true });

navToggle?.addEventListener('click', () => {
  const isOpen = navToggle.getAttribute('aria-expanded') === 'true';
  navToggle.setAttribute('aria-expanded', String(!isOpen));
  navToggle.setAttribute('aria-label', isOpen ? '打开导航' : '关闭导航');
  nav?.classList.toggle('open', !isOpen);
  document.body.style.overflow = isOpen ? '' : 'hidden';
});

nav?.querySelectorAll('a').forEach((link) => {
  link.addEventListener('click', () => {
    navToggle?.setAttribute('aria-expanded', 'false');
    navToggle?.setAttribute('aria-label', '打开导航');
    nav.classList.remove('open');
    document.body.style.overflow = '';
  });
});

document.querySelectorAll('[data-year]').forEach((node) => {
  node.textContent = String(new Date().getFullYear());
});

const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const revealNodes = document.querySelectorAll('.reveal');

if (prefersReducedMotion || !('IntersectionObserver' in window)) {
  revealNodes.forEach((node) => node.classList.add('visible'));
} else {
  const revealObserver = new IntersectionObserver(
    (entries, observer) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
      });
    },
    { rootMargin: '0px 0px -8% 0px', threshold: 0.08 },
  );

  revealNodes.forEach((node) => revealObserver.observe(node));
}

const repository = 'robeshell/MusicPlayerNext';
const releasePage = `https://github.com/${repository}/releases`;
const statusNode = document.querySelector('#release-status');

const setReleaseFallback = () => {
  if (statusNode) {
    statusNode.textContent = '暂无可下载版本，Web 版已开放。';
  }
};

fetch(`https://api.github.com/repos/${repository}/releases/latest`, {
  headers: { Accept: 'application/vnd.github+json' },
})
  .then((response) => {
    if (!response.ok) throw new Error(`GitHub API returned ${response.status}`);
    return response.json();
  })
  .then((release) => {
    const publishedAt = release.published_at
      ? new Intl.DateTimeFormat('zh-CN', { dateStyle: 'long' }).format(new Date(release.published_at))
      : '';
    if (statusNode) {
      statusNode.textContent = `${release.tag_name}${publishedAt ? ` · ${publishedAt}` : ''}`;
    }

    document.querySelectorAll('[data-asset]').forEach((card) => {
      const expectedName = card.getAttribute('data-asset');
      const asset = release.assets?.find((item) => item.name === expectedName);
      const link = card.querySelector('[data-download-link]');
      const label = card.querySelector('[data-download-label]');
      if (!link) return;

      link.href = asset?.browser_download_url || release.html_url || releasePage;
      if (asset && label) label.textContent = `下载 ${release.tag_name}`;
    });
  })
  .catch(setReleaseFallback);
