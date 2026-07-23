# Tableau workbook

`bixi_tableau_report.pdf` is the full written report with all visualisations
and narrative.

## Views

| # | View | Type | Question it answers |
|---|---|---|---|
| 1 | Number of Trips 2016–2017 by Month | Dual line, annotated | Is ridership growing, and when? |
| 2 | Percentage of Trips per Month | Dual line, % of total | Is the seasonal *shape* the same across years? |
| 3 | Percentage of Trips by Members, 2017 | Line, labelled | How does member share move through the season? |
| 4 | Top 10 Stations for Round Trips | Bar | Which stations skew leisure? |
| 5 | Member vs Non-Member Trip Duration | Grouped bar | Do the segments ride differently? |
| 6 | Average Trip Duration per Station | Symbol map, size + colour | Where are the long-duration stations? |
| 7 | Top 5 Stations by Duration | Filtered symbol map, annotated | Which specific stations, and what's near them? |
| 8 | Revenue per Trip Length | Bar, annotated | Which fare band drives casual revenue? |

## Techniques used

- Dual-axis and colour-encoded year comparison
- Percent-of-total table calculations scoped within year (not across)
- Symbol maps with dual encoding (size and colour on the same measure)
- Calculated fields for fare banding and membership labelling
- Annotations carrying the specific figure, so each chart states its own headline
- Filters on year, station, and membership driving multiple linked views
