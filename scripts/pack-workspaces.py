#!/usr/bin/env python3
import i3ipc
import time

SUFFIX = "_"
# DEBUG = True
# Instantiate an instance of the i3 connection object


def debug_print(*text):
    if DEBUG:
        for string in text:
            print(f"DEBUG: {string}")


def pack_workspaces(i3, e):
    debug_print(f"triggered {e.change} event for workspace {e.current.name}")
    # To get the current workspaces that are digits
    current_workspaces = [ws for ws in i3.get_workspaces() if ws.name.isdigit()]

    # Sort the workspaces by numbers, assuming the name of workspace is the number
    sorted_workspaces = sorted(current_workspaces, key=lambda ws: int(ws.name))

    # sort workspaces by output
    sorted_workspaces = sorted(
        sorted_workspaces,
        key=lambda ws: int(
            [o.rect.x for o in i3.get_outputs() if ws.output == o.name][0]
        ),
        reverse=False,
    )

    # check if the workspaces are already sorted
    if e.change != "empty" and (
        [int(ws.name) for ws in sorted_workspaces]
        == [int(ws.name) for ws in current_workspaces]
    ):
        debug_print("workspaces are already sorted")
        debug_print(
            [int(ws.name) for ws in current_workspaces],
            [int(ws.name) for ws in sorted_workspaces],
        )
        return

    # rename all workspaces to SUFFIX names (to avoid name conflicts)
    for i, workspace in enumerate(sorted_workspaces, start=1):
        # Send the rename command to i3 if the workspace is not already named correctly
        if int(workspace.name) != i:
            debug_print(
                "workspace {} is not named correctly should be {}".format(
                    workspace.name, i
                )
            )
            i3.command(
                'rename workspace "{}" to "{}{}"'.format(workspace.name, i, SUFFIX)
            )
            debug_print(
                "renaming workspace {} to {}{}".format(workspace.name, i, SUFFIX)
            )

    # get the temp workspaces
    current_workspaces = [ws for ws in i3.get_workspaces() if SUFFIX in ws.name]
    # Sort the workspaces by numbers, assuming the name of workspace is the new number removing the SUFFIX
    sorted_workspaces = sorted(
        current_workspaces, key=lambda ws: int(ws.name.split(SUFFIX)[0])
    )
    # sort workspaces by output
    sorted_workspaces = sorted(
        sorted_workspaces, key=lambda ws: ws.output, reverse=False
    )

    # Renumber the workspaces to use a continuous range
    for i, workspace in enumerate(sorted_workspaces, start=1):
        # Send the rename command to i3
        if workspace.name != i:
            extracted_name = workspace.name.split(SUFFIX)[0]
            i3.command(
                'rename workspace "{}" to "{}"'.format(workspace.name, extracted_name)
            )
            debug_print(
                "renaming workspace {} to {}".format(workspace.name, extracted_name)
            )


if __name__ == "__main__":
    # set DEBUG from command args
    import argparse

    # Create the parser
    parser = argparse.ArgumentParser(description="Pack workspaces")
    # Add the arguments
    parser.add_argument(
        "-d", "--debug", action="store_true", help="enable debug messages"
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="enable verbose messages"
    )
    parser.add_argument(
        "-s",
        "--suffix",
        type=str,
        help="suffix to use for temporary workspaces",
        default=SUFFIX,
    )

    # Execute the parse_args() method
    args = parser.parse_args()

    # set globals from args
    DEBUG = args.debug or args.verbose
    SUFFIX = args.suffix if args.suffix != "" else SUFFIX
    # print config info if debug
    debug_print("SUFFIX: {}".format(SUFFIX))

    # create the connection object
    i3 = i3ipc.Connection()

    # listen for init events (when new workspaces are created)
    i3.on("workspace::init", pack_workspaces)

    # listen for empty events (when a workspace is empty or closed)
    i3.on("workspace::empty", pack_workspaces)

    # run listener in a loop
    while True:
        # if restarted wait 5 seconds to start listening so the socket can be created
        if not DEBUG:
            time.sleep(5)
        debug_print("Listening for events...")
        i3.main()
        time.sleep(0.5)
        if DEBUG:
            break
