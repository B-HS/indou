'use client'

import { cn } from '@lib/utils'
import { Button } from '@ui/button'
import { ArrowUp } from 'lucide-react'
import { useEffect, useState } from 'react'

export const GoToTop = () => {
    const [isTop, setIsTop] = useState(true)

    useEffect(() => {
        const onScroll = () => setIsTop(window.scrollY === 0)
        onScroll()
        window.addEventListener('scroll', onScroll)
        return () => window.removeEventListener('scroll', onScroll)
    }, [])

    return (
        !isTop && (
            <Button
                variant='secondary'
                size='icon'
                aria-label='Scroll to top'
                className={cn('fixed bottom-9 right-9 transition-all z-50 size-9 border border-primary/10')}
                onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}>
                <ArrowUp />
            </Button>
        )
    )
}
