import uno
from com.sun.star.table.CellContentType import FORMULA


def replace_anchorarray():
    # get the component context from the running LibreOffice instance
    local_context = uno.getComponentContext()
    smgr = local_context.ServiceManager
    desktop = smgr.createInstanceWithContext("com.sun.star.frame.Desktop", local_context)
    doc = desktop.getCurrentComponent()

    anchor_dict = {}

    sheet = doc.Sheets[1]
    cell = sheet.getCellRangeByName("BJ54")
    print_cell_value(sheet, cell)


    for sheet in doc.Sheets:
        cursor = sheet.createCursor()
        cursor.gotoStartOfUsedArea(False)
        cursor.gotoEndOfUsedArea(True)

        start_col = cursor.RangeAddress.StartColumn
        end_col = cursor.RangeAddress.EndColumn
        start_row = cursor.RangeAddress.StartRow
        end_row = cursor.RangeAddress.EndRow

        # First pass: collect all target cells per anchor
        for r in range(start_row, end_row + 1):
            for c in range(start_col, end_col + 1):
                cell = sheet.getCellByPosition(c, r)
                if cell.Type == FORMULA:  # FORMULA
                    f = cell.Formula
                    if "{=_xlfn.anchorarray(" in f.lower():
                        print(f)
                        start = f.find("(") + 1
                        end = f.find(")")
                        anchor = f[start:end].strip()

                        # convert $Sheet.Cell -> 'Sheet'.Cell
                        if "." in anchor:
                            parts = anchor.split(".")
                            anchor = "'{}'.".format(parts[0].replace("$", "")) + parts[1]
                        # store the cell in the dictionary along with its sheet
                        if anchor not in anchor_dict:
                            anchor_dict[anchor] = []
                        anchor_dict[anchor].append((sheet, cell))



    for anchor, targets in anchor_dict.items():
        print(anchor)
        try:
            # Get the anchor sheet and cell from the first target
            anchor_sheet, _ = targets[0]
            anchor_cell = anchor_sheet.getCellRangeByName(anchor)
            anchor_formula = anchor_cell.Formula

            # Group targets by array range
            processed_arrays = set()

            for target_sheet, target_cell in targets:
                print("hi")
                try:
                    # Check if this target is part of an array formula
                    arr_range = None
                    try:
                        arr_range = target_cell.Formula
                    except AttributeError:
                        arr_range = None

                    print("hi2")

                    if arr_range is not None:
                        # get array bounds

                        print("good0")
                        print(arr_range)
                        start_col = arr_range.RangeAddress.StartColumn
                        end_col = arr_range.RangeAddress.EndColumn
                        start_row = arr_range.RangeAddress.StartRow
                        end_row = arr_range.RangeAddress.EndRow

                        print("good")
                        print(start_col + ", " + end_col + ", " + start_row + ", " + end_row)

                        top_left = (start_col, start_row)

                        if (target_sheet, top_left) not in processed_arrays:
                            # Clear all cells in the target array first
                            for r in range(start_row, end_row + 1):
                                for c in range(start_col, end_col + 1):
                                    target_sheet.getCellByPosition(c, r).ClearContents(1023)  # clear everything

                            # Assign the array formula to the top-left cell
                            top_cell = target_sheet.getCellByPosition(start_col, start_row)
                            try:
                                top_cell.FormulaArray = anchor_formula
                                processed_arrays.add((target_sheet, top_left))
                            except Exception as e:
                                print(f"Failed to assign array formula at {start_col},{start_row}: {e}")

                    else:
                        # Not an array formula, safe to assign normally
                        target_cell.FormulaArray = anchor_formula
                        print("wrong")
                except Exception as e:
                    print(f"Error replacing target cell {target_cell.CellAddress.Column},{target_cell.CellAddress.Row}: {e}")

        except Exception as e:
            print(f"Error processing anchor {anchor}: {e}")


    # Second pass: replace formulas
    # for anchor, targets in anchor_dict.items():
    #     print(anchor)
    #     try:
    #         # Get the anchor sheet and cell from the first target
    #         anchor_sheet, _ = targets[0]  # first occurrence
    #         anchor_cell = anchor_sheet.getCellRangeByName(anchor)
    #         anchor_formula = anchor_cell.Formula
    #
    #         # apply to all target cells
    #         for target_sheet, target_cell in targets:
    #             target_cell.Formula = anchor_formula
    #     except Exception as e:
    #         print(f"Error processing anchor {anchor}: {e}")

    print("Finished replacing _xlfn.ANCHORARRAY formulas.")

def print_cell_value(sheet, cell):
    col = cell.CellAddress.Column
    row = cell.CellAddress.Row
    value = None

    if cell.Type == 0:  # EMPTY
        value = "<empty>"
    elif cell.Type == 1:  # TEXT
        value = cell.String
    elif cell.Type == 2:  # FORMULA
        # Formula result
        if hasattr(cell, "Value"):
            value = cell.Value
        else:
            value = cell.String
    elif cell.Type == 3:  # VALUE (number)
        value = cell.Value
    elif cell.Type == 4:  # DATE
        value = cell.Value
    elif cell.Type == FORMULA:
        value = f"FFF ({cell.Type}) ({cell.Formula})"
    else:
        value = f"UNKNOWN ({cell.Type}) ({cell.Formula})"

    print(f"Sheet: {sheet.Name}, Cell: {col},{row}, Value: {value}")
