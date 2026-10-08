function formatXp(n) {
    if (n === 0) return "0xp";
    if (n >= 1000000) return (n / 1000000).toFixed(2) + "mil";
    if (n >= 1000) return (n / 1000).toFixed(1) + "k";
    return n + "xp";
}

function renderTimers(container, timers) {
    container.innerHTML = "";
    for (const t of timers) {
        const el = document.createElement("div");
        el.className = "timer-entry timer-" + t.colour;

        const nameSpan = document.createElement("span");
        nameSpan.className = "timer-name";
        nameSpan.textContent = t.name;

        if (t.group) {
            const badge = document.createElement("span");
            badge.className = "timer-group-badge";
            badge.textContent = "group";
            nameSpan.appendChild(badge);
        }

        const valSpan = document.createElement("span");
        valSpan.className = "timer-value";
        valSpan.textContent = t.minutes === -1 ? "???" : t.display;

        el.appendChild(nameSpan);
        el.appendChild(valSpan);

        el.addEventListener("click", function () {
            window.panel.post("reset", { name: t.name });
        });

        container.appendChild(el);
    }
}

function updateXp(xp) {
    document.getElementById("xp-window").textContent = formatXp(xp.window_xp);
    document.getElementById("xp-window-time").textContent = xp.window_time;

    const wRate = document.getElementById("xp-window-rate");
    wRate.textContent = xp.window_rate + "k/h";
    wRate.className = "xp-rate " + xp.window_colour;

    document.getElementById("xp-session").textContent = formatXp(xp.session_xp);
    document.getElementById("xp-session-time").textContent = xp.session_time;

    const sRate = document.getElementById("xp-session-rate");
    sRate.textContent = xp.session_rate + "k/h";
    sRate.className = "xp-rate " + xp.session_colour;
}

window.panel.on("update", function (data) {
    renderTimers(document.getElementById("kill-timers"), data.kill_timers);
    renderTimers(document.getElementById("visit-timers"), data.visit_timers);
    updateXp(data.xp);
});

document.getElementById("btn-xpreset").addEventListener("click", function () {
    window.panel.post("xpreset", {});
});

document.getElementById("btn-gsxp").addEventListener("click", function () {
    window.panel.post("gsxp", { all: false });
});

document.getElementById("btn-gsxp-all").addEventListener("click", function () {
    window.panel.post("gsxp", { all: true });
});

document.getElementById("btn-gsdt").addEventListener("click", function () {
    window.panel.post("gsdt", {});
});

document.getElementById("btn-reset-all").addEventListener("click", function () {
    window.panel.post("reset", { name: "" });
});

document.getElementById("btn-save").addEventListener("click", function () {
    window.panel.post("dtsave", {});
});

window.panel.post("ready", {});
