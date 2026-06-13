import { Reveal } from '@features/landing/reveal'
import { Kbd } from '@ui/kbd'

const ROWS: { keys: string[]; desc: string }[] = [
    { keys: ['⌥', '⇥'], desc: 'Open & cycle forward — release to focus' },
    { keys: ['⌥', '⇧', '⇥'], desc: 'Cycle backward' },
    { keys: ['←', '↑', '↓', '→'], desc: 'Move freely across the grid' },
    { keys: ['W', 'M', 'F', 'Q'], desc: 'Close · minimize · fullscreen · quit app' },
    { keys: ['Space'], desc: 'Lock open for mouse selection' },
]

export const ShortcutList = () => (
    <section className='py-8'>
        <Reveal className='flex flex-col gap-7'>
            <h2 className='text-2xl font-bold tracking-tight'>Shortcuts</h2>
            <div className='flex flex-col gap-2'>
                {ROWS.map((row) => (
                    <div key={row.desc} className='flex items-center gap-4 rounded-md border border-border bg-card px-4 py-3 shadow-xs'>
                        <div className='flex shrink-0 gap-1.5 sm:w-44'>
                            {row.keys.map((k) => (
                                <Kbd key={k}>{k}</Kbd>
                            ))}
                        </div>
                        <span className='text-sm text-muted-foreground'>{row.desc}</span>
                    </div>
                ))}
            </div>
        </Reveal>
    </section>
)
