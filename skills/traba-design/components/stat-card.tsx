export function StatCard({
  value,
  label,
  accent = false,
}: {
  value: string | number;
  label: string;
  accent?: boolean;
}) {
  return (
    <div
      className={`rounded-xl border p-4 text-center transition-colors ${
        accent
          ? "border-violet-20 bg-violet-10 hover:border-violet-40"
          : "border-gray-20 bg-white hover:border-gray-30"
      }`}
    >
      <div className={`text-[28px] font-semibold ${accent ? "text-violet-60" : "text-midnight-100"}`}>
        {value}
      </div>
      <div className="mt-1 text-[11px] font-medium uppercase tracking-wide text-gray-60">
        {label}
      </div>
    </div>
  );
}
