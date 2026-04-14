const variants = {
  green: "bg-green-10 text-green-70",
  red: "bg-red-10 text-red-70",
  orange: "bg-orange-10 text-orange-70",
  blue: "bg-blue-10 text-blue-80",
  violet: "bg-violet-10 text-violet-80",
  gray: "bg-gray-10 text-gray-70",
  midnight: "bg-midnight-10 text-midnight-80",
} as const;

export function Badge({
  variant = "gray",
  size = "default",
  children,
}: {
  variant?: keyof typeof variants;
  size?: "default" | "sm";
  children: React.ReactNode;
}) {
  return (
    <span
      className={`inline-block whitespace-nowrap rounded font-sans font-medium ${variants[variant]} ${
        size === "sm" ? "px-1.5 py-0.5 text-[10px]" : "px-2 py-1 text-[11px]"
      }`}
    >
      {children}
    </span>
  );
}
