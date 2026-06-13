import { cn } from '@lib/utils'
import { FC, PropsWithChildren } from 'react'

export const Kbd: FC<PropsWithChildren<{ className?: string }>> = ({ children, className }) => (
    <kbd
        className={cn(
            'inline-flex h-6 min-w-6 items-center justify-center rounded-md border border-border bg-secondary px-1.5 font-mono text-xs font-medium text-secondary-foreground shadow-xs',
            className,
        )}>
        {children}
    </kbd>
)
