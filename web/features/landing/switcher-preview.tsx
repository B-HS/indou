'use client'

import { cn } from '@lib/utils'
import { motion, useReducedMotion } from 'motion/react'
import { useEffect, useState } from 'react'

const WINDOWS = ['Finder', 'Safari', 'Figma', 'Code', 'Terminal', 'Music']

export const SwitcherPreview = () => {
    const reduce = useReducedMotion()
    const [selected, setSelected] = useState(0)

    useEffect(() => {
        if (reduce) return
        const id = setInterval(() => setSelected((s) => (s + 1) % WINDOWS.length), 1150)
        return () => clearInterval(id)
    }, [reduce])

    return (
        <div className='mt-10 w-full max-w-2xl rounded-xl border border-border bg-card p-4 shadow-sm'>
            <div className='grid grid-cols-3 gap-3'>
                {WINDOWS.map((name, i) => (
                    <div key={name} className='relative flex aspect-[4/3] flex-col gap-2 rounded-lg border border-border bg-background p-3'>
                        {selected === i && (
                            <motion.div
                                layoutId='indou-selection'
                                className='absolute inset-0 rounded-lg border-2 border-primary bg-secondary'
                                transition={{ type: 'spring', stiffness: 380, damping: 30 }}
                            />
                        )}
                        <div className='relative flex-1 rounded-md border border-border bg-muted' />
                        <span className={cn('relative text-xs transition-colors', selected === i ? 'font-medium text-foreground' : 'text-muted-foreground')}>
                            {name}
                        </span>
                    </div>
                ))}
            </div>
        </div>
    )
}
