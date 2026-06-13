'use client'

import { Button } from '@ui/button'
import { Monitor, Moon, Sun } from 'lucide-react'
import { useTheme } from 'next-themes'
import { useEffect, useState } from 'react'

const order = ['system', 'light', 'dark'] as const

export const ThemeToggle = () => {
    const [mounted, setMounted] = useState(false)
    const { theme, setTheme } = useTheme()

    useEffect(() => setMounted(true), [])

    const current = (theme ?? 'system') as (typeof order)[number]
    const next = order[(order.indexOf(current) + 1) % order.length]

    return (
        <Button
            variant='ghost'
            size='icon'
            aria-label='Toggle theme'
            onClick={() => setTheme(next)}>
            {!mounted ? <Monitor /> : current === 'dark' ? <Moon /> : current === 'light' ? <Sun /> : <Monitor />}
        </Button>
    )
}
