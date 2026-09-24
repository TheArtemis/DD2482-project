const shortenForm = document.querySelector("#shorten-form");
const statsForm = document.querySelector("#stats-form");
const result = document.querySelector("#result");
const shortUrl = document.querySelector("#short-url");
const copyButton = document.querySelector("#copy-button");
const statsCard = document.querySelector("#stats-card");
const deleteButton = document.querySelector("#delete-button");
let selectedCode = null;

async function api(path, options = {}) {
  const response = await fetch(path, options);
  if (!response.ok) {
    let message = "Something went wrong. Please try again.";
    try {
      const body = await response.json();
      message = Array.isArray(body.detail) ? body.detail[0]?.msg : body.detail;
    } catch (_) {
      // Preserve the generic message when the response is not JSON.
    }
    throw new Error(message || "Request failed");
  }
  return response.status === 204 ? null : response.json();
}

function setBusy(form, busy) {
  const button = form.querySelector("button[type='submit']");
  button.disabled = busy;
  button.textContent = busy ? "Working…" : button.dataset.label;
}

document.querySelectorAll("form button[type='submit']").forEach((button) => {
  button.dataset.label = button.textContent;
});

shortenForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const message = document.querySelector("#form-message");
  message.textContent = "";
  result.hidden = true;
  setBusy(shortenForm, true);
  try {
    const data = await api("/links", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ destination_url: shortenForm.destination.value }),
    });
    shortUrl.textContent = data.short_url;
    shortUrl.href = data.short_url;
    result.hidden = false;
    document.querySelector("#code").value = data.code;
  } catch (error) {
    message.textContent = error.message;
  } finally {
    setBusy(shortenForm, false);
  }
});

copyButton.addEventListener("click", async () => {
  await navigator.clipboard.writeText(shortUrl.href);
  copyButton.textContent = "Copied!";
  window.setTimeout(() => { copyButton.textContent = "Copy"; }, 1600);
});

statsForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  const message = document.querySelector("#stats-message");
  message.textContent = "";
  statsCard.hidden = true;
  setBusy(statsForm, true);
  try {
    const code = statsForm.code.value.trim();
    const data = await api(`/links/${encodeURIComponent(code)}/stats`);
    selectedCode = data.code;
    document.querySelector("#redirect-count").textContent = data.redirect_count;
    const destination = document.querySelector("#stats-destination");
    destination.textContent = data.destination_url;
    destination.href = data.destination_url;
    document.querySelector("#created-at").textContent = new Date(data.created_at).toLocaleString();
    const status = document.querySelector("#link-status");
    status.textContent = data.is_active ? "Active" : "Disabled";
    status.classList.toggle("inactive", !data.is_active);
    deleteButton.hidden = !data.is_active;
    statsCard.hidden = false;
  } catch (error) {
    message.textContent = error.message;
  } finally {
    setBusy(statsForm, false);
  }
});

deleteButton.addEventListener("click", async () => {
  if (!selectedCode || !window.confirm("Disable this short link? It will stop redirecting.")) return;
  try {
    await api(`/links/${encodeURIComponent(selectedCode)}`, { method: "DELETE" });
    statsForm.requestSubmit();
  } catch (error) {
    document.querySelector("#stats-message").textContent = error.message;
  }
});

api("/version")
  .then((data) => { document.querySelector("#version").textContent = `Version ${data.version}`; })
  .catch(() => { document.querySelector("#version").textContent = "Version unavailable"; });

