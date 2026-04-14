/**
 * 52px topbar with breadcrumb navigation and action buttons.
 * Sits to the right of the 154px sidebar.
 */

interface Breadcrumb {
  label: string;
  href?: string;
}

export function Topbar({
  breadcrumbs,
  actions,
}: {
  breadcrumbs: Breadcrumb[];
  actions?: React.ReactNode;
}) {
  return (
    <header className="fixed left-[154px] right-0 top-0 z-40 flex h-[52px] items-center justify-between border-b border-gray-20 bg-white px-6">
      <div className="flex items-center gap-2">
        {breadcrumbs.map((crumb, i) => {
          const isLast = i === breadcrumbs.length - 1;
          return (
            <span key={i} className="flex items-center gap-2">
              {i > 0 && (
                <svg className="text-gray-30" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
                  <path d="M9 18l6-6-6-6" />
                </svg>
              )}
              {isLast ? (
                <span className="text-sm font-medium text-midnight-100">{crumb.label}</span>
              ) : (
                <a href={crumb.href} className="text-sm text-gray-70 no-underline hover:text-violet-60">
                  {crumb.label}
                </a>
              )}
            </span>
          );
        })}
      </div>
      {actions && <div className="flex items-center gap-2">{actions}</div>}
    </header>
  );
}
