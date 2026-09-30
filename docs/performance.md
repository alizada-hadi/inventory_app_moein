# Local SQLite performance baseline

## Scope

The primary list screens are database-backed and retain at most the rows the
user has paged into. Page size is 50 for products, sales, and purchases. Price,
purchase, and sale history shown on Product Details is limited to five rows.

## Query strategy

- Products use keyset pagination ordered by `updated_at DESC, id DESC`.
- Sales use keyset pagination ordered by `sale_date DESC, id DESC`.
- Purchases use keyset pagination ordered by `purchase_date DESC, id DESC`.
- Product name/barcode search is executed in SQLite after a 300 ms debounce.
- Sales and purchases list queries join `products` once and return a lightweight
  list row, avoiding one product query per rendered row.
- Dashboard counts, low-stock rows, and recent activity are bounded SQL
  aggregate/limit queries; dashboard does not load a transaction table.

## Cursors

```text
ProductCursor(updatedAt, id)
SaleCursor(saleDate, id)
PurchaseCursor(purchaseDate, id)
```

The second key is required because timestamps are not unique.

## Indexes

Migration 10 adds:

- `products(updated_at DESC, id DESC)` for product page traversal.
- `sales(sale_date DESC, id DESC)` for the sales feed.
- `sales(product_id, sale_date DESC, id DESC)` for product history.
- `purchases(purchase_date DESC, id DESC)` for the purchases feed.
- `purchases(product_id, purchase_date DESC, id DESC)` for product history.
- `stock_movements(movement_date DESC, id DESC)` for recent activity.
- `stock_movements(product_id, movement_date DESC, id DESC)` for product activity.
- `product_price_history(product_id, effective_date DESC, id DESC)` for price history.

The existing name and barcode indexes remain for exact/prefix lookup. The
current contains-style search (`%term%`) is SQLite-side but can still require a
scan; FTS is intentionally out of scope for this local MVP.

## Important SQL shapes

```sql
WHERE updated_at < ? OR (updated_at = ? AND id < ?)
ORDER BY updated_at DESC, id DESC
LIMIT 51
```

```sql
SELECT COUNT(*) FROM sales
WHERE sale_date >= ? AND sale_date < ?
```

```sql
SELECT name, current_stock_base, unit
FROM products
WHERE current_stock_base <= restock_level
ORDER BY current_stock_base ASC, name COLLATE NOCASE ASC
LIMIT 5
```

## State and rendering

Riverpod pagination state distinguishes initial loading, refresh, and loading
more. Generation IDs prevent an old product search response from replacing a
newer search. Scroll listeners trigger one guarded `loadMore` request. Lists
use lazy builders; rows do not query SQLite.

## Operational reports

Reports are separated into sales, purchases, and inventory controllers. Typed
transaction and inventory filters are converted to Gregorian ISO boundaries in
the repository; Jalali values remain presentation-level UI state. Report pages
use the same 50-row keyset pagination as the primary lists. Sales and purchases
also execute independent `COUNT`/currency-split aggregate queries, so totals
represent the complete filtered dataset rather than only the loaded page.

The report product selector searches SQLite and returns one page of matches.
Inventory status predicates (`current_stock_base = 0`, `> 0`, and threshold
comparisons) are also evaluated by SQLite. Report filters are held in the
screen/provider lifetime and are not persisted.

## Benchmark baseline

The repository now has the production page boundaries needed for the target
dataset sizes (10,000 products, 100,000 sales, 100,000 purchases, and large
movement/history tables). A device benchmark should be run with release mode
on a mid-range Android device using those exact counts. This development
environment does not provide a representative Android device, so no fabricated
wall-clock timings are recorded here. The before baseline was unbounded table
loads; the after baseline is 50-row pages, bounded history, and aggregate
dashboard queries.

## Remaining risks

- Contains-style product search may scan the products table for arbitrary
  substrings. A future measured need could justify SQLite FTS5.
- Very long sessions retain the rows the user has paged through in Riverpod.
  A windowed list should only be added if memory profiling demonstrates growth
  on target devices.
