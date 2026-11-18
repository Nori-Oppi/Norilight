#pragma once

#include <QString>

// Norilight: "Reset Norilight" (Settings > Network & diagnostics, or
// "Norilight --reset"). Nothing is deleted: the settings are moved to a dated
// backup next to where they are kept, and Norilight starts as on its first run,
// in the first-start wizard. Moving the backup back undoes it (the Norilight-Guide wiki page).
namespace SettingsReset
{
    // Moves the settings to the backup. Returns where the backup went, or an
    // empty string if there was nothing to move or the move failed (error set).
    QString moveToBackup(QString* error = nullptr);

    // Handles "--reset" on the command line, before anything reads the
    // settings: waits for the Norilight that asked for the reset to exit,
    // then moves the settings away. Returns true if a reset was asked for;
    // message says where the settings went, or why they stayed.
    bool handleCommandLine(int argc, char* argv[], QString* message);

    // Starts a new Norilight that resets the settings once this one has
    // exited. The caller quits right after. False if it couldn't be started.
    bool restartIntoReset();
}
