'use client'

import { motion, useReducedMotion } from 'motion/react'
import { FC, PropsWithChildren } from 'react'

type RevealProps = PropsWithChildren<{ className?: string; delay?: number }>

export const Reveal: FC<RevealProps> = ({ children, className, delay = 0 }) => {
    const reduce = useReducedMotion()
    return (
        <motion.div
            className={className}
            initial={reduce ? false : { opacity: 0, y: 16 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-8% 0px' }}
            transition={{ duration: 0.5, ease: [0.2, 0.8, 0.2, 1], delay }}>
            {children}
        </motion.div>
    )
}
