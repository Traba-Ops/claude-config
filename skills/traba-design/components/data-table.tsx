/**
 * Styled data table with Traba design system conventions.
 * Headers are uppercase labels. Rows have hover states and bottom borders.
 */

interface Column<T> {
  key: string;
  label: string;
  render?: (row: T) => React.ReactNode;
}

export function DataTable<T extends Record<string, unknown>>({
  columns,
  data,
  onRowClick,
}: {
  columns: Column<T>[];
  data: T[];
  onRowClick?: (row: T) => void;
}) {
  return (
    <div className="overflow-hidden rounded-lg border border-gray-20">
      <table className="w-full border-collapse text-[13px]">
        <thead>
          <tr className="bg-gray-10">
            {columns.map((col) => (
              <th
                key={col.key}
                className="px-3 py-2.5 text-left text-[11px] font-medium uppercase tracking-wide text-gray-60"
              >
                {col.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {data.map((row, i) => (
            <tr
              key={i}
              className={`border-t border-gray-20 text-midnight-100 transition-colors hover:bg-[#FAFAFA] ${
                onRowClick ? "cursor-pointer" : ""
              }`}
              onClick={() => onRowClick?.(row)}
            >
              {columns.map((col) => (
                <td key={col.key} className="px-3 py-3">
                  {col.render ? col.render(row) : String(row[col.key] ?? "")}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
