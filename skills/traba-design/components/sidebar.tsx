/**
 * 154px sidebar with logo, navigation sections, and user profile.
 * Adapt nav items and sections to your app.
 */

interface NavItem {
  label: string;
  href: string;
  active?: boolean;
}

interface NavSection {
  label: string;
  items: NavItem[];
}

export function Sidebar({
  sections,
  user,
}: {
  sections: NavSection[];
  user?: { name: string; role: string };
}) {
  return (
    <aside className="fixed inset-y-0 left-0 z-50 flex w-[154px] flex-col border-r border-gray-20 bg-white">
      {/* Logo */}
      <div className="flex items-center gap-2 px-4 py-4">
        <div className="flex size-7 items-center justify-center rounded-md bg-violet-60 text-xs font-semibold text-white">
          T
        </div>
        <span className="text-sm font-semibold text-midnight-100">Traba</span>
      </div>

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto px-2">
        {sections.map((section) => (
          <div key={section.label} className="mb-4">
            <div className="px-2 py-1 text-[10px] font-medium uppercase tracking-[0.8px] text-gray-50">
              {section.label}
            </div>
            {section.items.map((item) => (
              <a
                key={item.href}
                href={item.href}
                className={`block rounded-lg px-2 py-2 text-[13px] font-medium no-underline transition-colors ${
                  item.active
                    ? "bg-violet-10 text-violet-60"
                    : "text-gray-70 hover:bg-gray-10 hover:no-underline"
                }`}
              >
                {item.label}
              </a>
            ))}
          </div>
        ))}
      </nav>

      {/* User profile */}
      {user && (
        <div className="border-t border-gray-20 px-3 py-3">
          <div className="flex items-center gap-2">
            <div className="flex size-7 items-center justify-center rounded-full bg-violet-10 text-xs font-medium text-violet-60">
              {user.name[0]}
            </div>
            <div className="min-w-0">
              <div className="truncate text-xs font-medium text-midnight-100">{user.name}</div>
              <div className="truncate text-[10px] text-gray-60">{user.role}</div>
            </div>
          </div>
        </div>
      )}
    </aside>
  );
}
