const colors = {
  active: "bg-green-60",
  stale: "bg-orange-60",
  inactive: "bg-red-60",
} as const;

export function StatusDot({ status }: { status: keyof typeof colors }) {
  return <span className={`inline-block size-[7px] shrink-0 rounded-full ${colors[status]}`} />;
}
