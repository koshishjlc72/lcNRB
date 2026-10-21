# lcNRB contributor notes

- Treat the NRB website and workbooks as external, changing inputs.
- Never add an indicator without verifying its source workbook and parser.
- Preserve original units, fiscal-period labels, source URL, hash, and vintage.
- Add a local fixture or a focused regression test for every parser change.
- Do not silently recover from unexpected workbook layouts.
- Keep runtime cache writes outside the installed package directory.
- The package is independent and must not imply NRB endorsement.
