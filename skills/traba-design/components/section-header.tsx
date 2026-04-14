export function SectionHeader({ children }: { children: React.ReactNode }) {
  return (
    <h4 className="mb-2.5 text-[11px] font-medium uppercase tracking-wide text-gray-60">
      {children}
    </h4>
  );
}
