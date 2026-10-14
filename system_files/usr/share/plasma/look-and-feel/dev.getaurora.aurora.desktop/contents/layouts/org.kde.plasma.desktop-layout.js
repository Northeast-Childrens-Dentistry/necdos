loadTemplate("org.kde.plasma.desktop.defaultPanel")

const allPanels = panels();

for (let i = 0; i < allPanels.length; ++i) {
    const panel = allPanels[i];
    const widgets = panel.widgets();

    for (let j = 0; j < widgets.length; ++j) {
        const widget = widgets[j];

        if (widget.type === "org.kde.plasma.icontasks") {
            widget.currentConfigGroup = ["General"];

            // NECD OS taskbar: browser and practice apps first.
            widget.writeConfig("launchers", [
                "applications:google-chrome.desktop",
                "applications:necd-carestack.desktop",
                "applications:necd-iris.desktop",
                "preferred://filemanager",
                "applications:io.github.kolunmi.Bazaar.desktop"
            ]);
            widget.reloadConfig();
        }
    }
}
