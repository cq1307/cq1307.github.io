(function () {
  const posts = (Array.isArray(window.BLOG_POSTS) ? window.BLOG_POSTS : [])
    .slice()
    .sort((a, b) => String(b.date || "").localeCompare(String(a.date || "")));
  const defaultCategories = ["语言", "Android", "Windows", "CTF", "IoT", "Game", "Reverse_Wiki"];

  const root = document.documentElement;
  const savedTheme = localStorage.getItem("theme");
  if (savedTheme) {
    root.dataset.theme = savedTheme;
  } else if (window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches) {
    root.dataset.theme = "dark";
  }

  function escapeHtml(value) {
    return String(value ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function slug(value) {
    return String(value || "item")
      .trim()
      .toLowerCase()
      .replace(/[^\w\u4e00-\u9fa5-]+/g, "-")
      .replace(/^-+|-+$/g, "") || "item";
  }

  function categoriesOf(post) {
    if (Array.isArray(post.categories)) return post.categories;
    if (post.category) return [post.category];
    return [];
  }

  function tagsOf(post) {
    return Array.isArray(post.tags) ? post.tags : [];
  }

  function categoryText(post) {
    const categories = categoriesOf(post);
    return categories.length ? categories.join(" > ") : "未分类";
  }

  function renderHomePosts() {
    const list = document.querySelector("[data-post-list]");
    if (!list) return;
    if (!posts.length) {
      list.innerHTML = `<p class="empty-state">暂无文章</p>`;
      return;
    }
    list.innerHTML = posts.map((post) => {
      const categories = categoryText(post);
      const tag = tagsOf(post)[0];
      return `
        <article class="post-card">
          <a href="${escapeHtml(post.url)}">
            <h3>${escapeHtml(post.title)}</h3>
            <p>${escapeHtml(post.summary || "")}</p>
          </a>
          <footer>
            <span>${escapeHtml(post.date || "")}</span>
            <a href="categories.html#${slug(categories)}">${escapeHtml(categories)}</a>
            ${tag ? `<a href="tags.html#${slug(tag)}">#${escapeHtml(tag)}</a>` : ""}
          </footer>
        </article>
      `;
    }).join("");
  }

  function renderArchives() {
    const timeline = document.querySelector("[data-archives]");
    if (!timeline) return;
    if (!posts.length) {
      timeline.innerHTML = `<p class="empty-state">暂无归档</p>`;
      return;
    }
    const byYear = new Map();
    posts.forEach((post) => {
      const year = String(post.date || "未归档").slice(0, 4);
      if (!byYear.has(year)) byYear.set(year, []);
      byYear.get(year).push(post);
    });
    timeline.innerHTML = [...byYear.entries()].map(([year, items]) => `
      <h2>${escapeHtml(year)}</h2>
      ${items.map((post) => `
        <a href="${escapeHtml(post.url)}">
          <time>${escapeHtml(String(post.date || "").slice(5) || "--")}</time>
          <span>${escapeHtml(post.title)}</span>
        </a>
      `).join("")}
    `).join("");
  }

  function renderCategories() {
    const container = document.querySelector("[data-categories]");
    if (!container) return;
    const groups = new Map();
    posts.forEach((post) => {
      const name = categoryText(post);
      if (!groups.has(name)) groups.set(name, []);
      groups.get(name).push(post);
    });
    container.innerHTML = [...groups.entries()].map(([name, items]) => `
      <section id="${slug(name)}" class="simple-card">
        <h2>${escapeHtml(name)}</h2>
        <p>${items.length} 篇文章</p>
        ${items.map((post) => `<a href="${escapeHtml(post.url)}">${escapeHtml(post.title)}</a>`).join("")}
      </section>
    `).join("");
  }

  function renderTags() {
    const cloud = document.querySelector("[data-tags]");
    if (!cloud) return;
    const groups = new Map();
    posts.forEach((post) => {
      tagsOf(post).forEach((tag) => {
        if (!groups.has(tag)) groups.set(tag, []);
        groups.get(tag).push(post);
      });
    });
    cloud.innerHTML = [...groups.entries()].map(([tag, items]) => {
      const first = items[0];
      return `<a id="${slug(tag)}" href="${escapeHtml(first.url)}">#${escapeHtml(tag)} <small>${items.length}</small></a>`;
    }).join("");
  }

  function renderTaxonomyViews() {
    const categoriesContainer = document.querySelector("[data-categories]");
    if (categoriesContainer) {
      const groups = new Map();
      posts.forEach((post) => {
        const name = categoryText(post);
        if (!groups.has(name)) groups.set(name, []);
        groups.get(name).push(post);
      });
      const categoryEntries = groups.size
        ? [...groups.entries()]
        : defaultCategories.map((name) => [name, []]);
      categoriesContainer.innerHTML = `
        <section class="taxonomy-board" aria-label="分类目录">
          ${renderTaxonomyGroups(categoryEntries, false)}
        </section>
      `;
    }

    const tagsContainer = document.querySelector("[data-tags]");
    if (tagsContainer) {
      const groups = new Map();
      posts.forEach((post) => {
        tagsOf(post).forEach((tag) => {
          if (!groups.has(tag)) groups.set(tag, []);
          groups.get(tag).push(post);
        });
      });
      tagsContainer.classList.add("taxonomy-board");
      tagsContainer.innerHTML = groups.size
        ? renderTaxonomyGroups([...groups.entries()].map(([tag, items]) => [`#${tag}`, items]), true)
        : '<p class="empty-state">暂无标签</p>';
    }
  }

  function renderTaxonomyGroups(entries, isTag) {
    return entries.map(([name, items]) => {
      const id = isTag ? slug(String(name).replace(/^#/, "")) : slug(name);
      const title = isTag ? name : String(name).split(" > ").join(" / ");
      return `
        <section id="${id}" class="taxonomy-group">
          <header class="taxonomy-group-head">
            <h2>${escapeHtml(title)}</h2>
            <span>${items.length}</span>
          </header>
          <div class="taxonomy-posts">
            ${items.map((post) => `
              <a href="${escapeHtml(post.url)}">
                <span class="taxonomy-post-title">${escapeHtml(post.title)}</span>
                <time>${escapeHtml(post.date || "")}</time>
              </a>
            `).join("")}
          </div>
        </section>
      `;
    }).join("");
  }

  renderHomePosts();
  renderArchives();
  renderCategories();
  renderTags();
  renderTaxonomyViews();

  const navToggle = document.querySelector(".nav-toggle");
  const navMenu = document.querySelector(".nav-menu");
  if (navToggle && navMenu) {
    navToggle.addEventListener("click", () => {
      const isOpen = navMenu.classList.toggle("open");
      navToggle.setAttribute("aria-expanded", String(isOpen));
    });
  }

  document.querySelectorAll("[data-theme-toggle]").forEach((button) => {
    button.addEventListener("click", () => {
      const next = root.dataset.theme === "dark" ? "light" : "dark";
      root.dataset.theme = next;
      localStorage.setItem("theme", next);
    });
  });

  const progress = document.getElementById("progress");
  const topButton = document.querySelector("[data-back-top]");
  function updateScrollUi() {
    const max = document.documentElement.scrollHeight - window.innerHeight;
    const ratio = max > 0 ? window.scrollY / max : 0;
    if (progress) progress.style.width = `${Math.min(100, ratio * 100)}%`;
    if (topButton) topButton.classList.toggle("visible", window.scrollY > 420);
  }
  updateScrollUi();
  window.addEventListener("scroll", updateScrollUi, { passive: true });
  if (topButton) {
    topButton.addEventListener("click", () => window.scrollTo({ top: 0, behavior: "smooth" }));
  }

  const typingEl = document.querySelector("[data-typing]");
  if (typingEl) {
    const text = typingEl.dataset.typing || "";
    typingEl.textContent = "";
    let index = 0;
    const timer = window.setInterval(() => {
      typingEl.textContent = text.slice(0, index);
      index += 1;
      if (index > text.length) window.clearInterval(timer);
    }, 70);
  }

  const modal = document.querySelector("[data-search-modal]");
  const input = document.querySelector("[data-search-input]");
  const results = document.querySelector("[data-search-results]");

  function openSearch() {
    if (!modal) return;
    modal.hidden = false;
    setTimeout(() => input && input.focus(), 0);
    renderSearch("");
  }

  function closeSearch() {
    if (modal) modal.hidden = true;
  }

  function renderSearch(query) {
    if (!results) return;
    const normalized = query.trim().toLowerCase();
    const matched = normalized
      ? posts.filter((post) => `${post.title} ${categoryText(post)} ${tagsOf(post).join(" ")} ${post.summary}`.toLowerCase().includes(normalized))
      : posts;

    results.innerHTML = matched.length
      ? matched.map((post) => (
        `<a href="${escapeHtml(post.url)}"><strong>${escapeHtml(post.title)}</strong><span>${escapeHtml(categoryText(post))} - ${escapeHtml(post.summary || "")}</span></a>`
      )).join("")
      : "<p>没有找到相关文章。</p>";
  }

  document.querySelectorAll("[data-open-search]").forEach((button) => {
    button.addEventListener("click", openSearch);
  });
  document.querySelectorAll("[data-close-search]").forEach((button) => {
    button.addEventListener("click", closeSearch);
  });
  if (modal) {
    modal.addEventListener("click", (event) => {
      if (event.target === modal) closeSearch();
    });
  }
  if (input) {
    input.addEventListener("input", () => renderSearch(input.value));
  }
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") closeSearch();
    if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
      event.preventDefault();
      openSearch();
    }
  });

  const toc = document.querySelector("[data-toc]");
  const article = document.querySelector("[data-article]");
  if (toc && article) {
    const headings = Array.from(article.querySelectorAll("h2[id]"));
    toc.innerHTML = headings.map((heading) => (
      `<a href="#${heading.id}">${escapeHtml(heading.textContent)}</a>`
    )).join("");
  }
})();


