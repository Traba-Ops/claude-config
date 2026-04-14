export function FilterButton({
  active = false,
  onClick,
  children,
}: {
  active?: boolean;
  onClick?: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      className={`cursor-pointer rounded-lg border px-3.5 py-[7px] font-sans text-[13px] font-medium transition-all duration-150 ${
        active
          ? "border-violet-60 bg-violet-10 text-violet-60"
          : "border-gray-20 bg-white text-gray-70 hover:border-gray-30 hover:bg-gray-10"
      }`}
      onClick={onClick}
    >
      {children}
    </button>
  );
}
