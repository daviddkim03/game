import { Radio } from "@base-ui/react/radio"
import { RadioGroup } from "@base-ui/react/radio-group"

import { cn } from "@/lib/utils"
import { COLORS } from "@/pages/schedule/model"

type ColorSwatchesProps = {
  value: string
  onValueChange: (color: string) => void
  "aria-label"?: string
  "aria-labelledby"?: string
  className?: string
}

/** Single-choice color picker; arrow keys move between swatches. */
export function ColorSwatches({
  value,
  onValueChange,
  className,
  ...props
}: ColorSwatchesProps) {
  return (
    <RadioGroup
      value={value}
      onValueChange={(next) => onValueChange(next as string)}
      className={cn("flex flex-wrap items-center gap-1.5", className)}
      {...props}
    >
      {COLORS.map((color) => (
        <Radio.Root
          key={color.value}
          value={color.value}
          aria-label={color.name}
          title={color.name}
          style={{ backgroundColor: color.value }}
          className="size-5 shrink-0 rounded-[5px] ring-offset-2 ring-offset-background transition-transform outline-none hover:scale-110 focus-visible:ring-2 focus-visible:ring-ring data-checked:scale-110 data-checked:ring-2 data-checked:ring-foreground"
        />
      ))}
    </RadioGroup>
  )
}
