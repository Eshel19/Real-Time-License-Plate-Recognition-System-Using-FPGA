War Story: Building a Real-Time FPGA ALPR System

The Journey of Dar Eshel Epstein

## Chapter 0 — The Spark That Lit the Fire

It didn't start with fear—it started with hype, and a real hunger to do something that mattered. I’d already gotten my hands dirty with FPGAs before, thanks to a couple of college projects, but those were mostly about building IP cores or running demo designs—interesting, sure, but nothing that felt truly “real-world.”

I wanted to do more than just write a module and load memory. I wanted to use an FPGA for something that actually does something, something tangible, not just a lab assignment. So I went to my advisor with a simple question:

“What if I do some kind of real image processing? Maybe detection, maybe something practical, just to see what the hardware can actually do?”

He considered it and said, “Digit detection seems respectable, definitely doable for one student.” That sounded like a good challenge. I could learn a lot, and maybe build something I’d actually use.

Then the project admin weighed in. “Why not do a full ALPR system?” Just like that, the scope exploded—from digits to license plates, from a single algorithm to a whole pipeline.

It was daunting, but the idea got me hyped. Even though I barely knew anything about practical image processing at that point, I was ready to throw myself in.

Only after I started exploring the board—seeing the ARM CPU and the FPGA sitting side-by-side—did the vision for a hybrid solution really come together in my mind: CPU for preprocessing, FPGA for the heavy-lifting OCR.

I had the concept, the plan, and now, I needed to see if I could actually pull it off on real hardware.



## Chapter 1 — A Board, a Dream, and a Dead OS

The vision was mapped out. The goal: a real hybrid system, not just an academic exercise. I needed hardware—something I could bend to my will.

That’s when my advisor said the college had just acquired a DE10-Standard board. I checked it out: dual-core ARM, a decent FPGA, and a pile of example projects.

I thought, “Maybe this is my shot.”

But the moment I got it home, reality hit. The supplied OS was ancient—nothing would compile, not C++, not OpenCV, not even basic tools. I spent weeks lost in “OS hell,” searching every forum, chasing every lead.

No progress.

Finally, something in me snapped. I decided: if the system won’t work for me, I’ll build my own. I didn’t know the kernel, didn’t know U-Boot, but I dug up an old guide for the DE10-Nano, adapted it for the Standard, and hacked my way through building a custom Arch Linux image from scratch.

Finally—success. It booted. OpenCV ran. Even ONNX models would execute.

But just as I was ready to celebrate, I ran a “real-time YOLO” test and got 340ms per frame. That’s not “real-time.”

I’d made it through hell—only to discover my first solution was useless.



## Chapter 2 — Chasing Ghosts in Real Time

I started panicking. I tried old methods. Haar cascades. Cascade classifiers. Nothing. Not even garbage. Just silence.

First, I tried running the Nanodet model through ONNX. It ran—but painfully slow. Completely unusable for real-time. So I kept looking.

That's when I learned about NCNN. But compiling it for the DE10 wasn't a walk in the park. Every build attempt threw obscure errors. I didn't know what half of them meant, and fixing them felt like stabbing in the dark. Once I finally got it to compile, the Nanodet C++ demo didn't work with my model at all—wrong dimensions, wrong layout. I had to rewrite parts of the loader, patch tensor shapes, and manually align everything just to get it to run inference.

Eventually, I resized the input down to 120×120. Quality dropped—but finally, it worked. A license plate, detected.

I didn't care if some junk got through—what mattered was that 87% of the time, the system didn't miss a license plate.

I just stared at the screen. I whispered: It worked. And for the first time, I felt something shift. The risk had a crack of light.





## Chapter 3 — The Wall of Preprocessing

FPGAs don't like unpredictable input formats. The height had to be fixed at 16 pixels, but the width could vary—as long as the logic could manage it.

I tried Canny edge detection. 120ms. Useless. Too slow, too fragile.

So I ditched complexity and focused on speed. I couldn't segment individual characters cleanly using linear image processing—not reliably, not fast enough. Instead, I made a compromise: flatten the plate into a single, straight horizontal strip. Even for multi-line license plates, I processed them into a single 16-pixel-tall line with flexible width.

No bounding boxes. No character segmentation. Just a straightened plate strip—corrected for tilt, aligned to 16-pixel height, and stretched to flexible width. It wasn't pretty, but it was readable. And it gave the FPGA exactly what it needed to process reliably.

That was enough.



## Chapter 4 — The First Heartbreak

I had no idea how to do AI on an FPGA. CNNs made sense in Python—not in logic gates. So I thought: binary classifiers per class. Run them one-by-one. It seemed simple.

It wasn't.

I spent 2 months building the hardware. Every bit placed by hand. The logic was solid. The idea made sense.

It detected nothing.

I thought I'd lose it. I told myself: Maybe I'm just not good enough. Maybe I shouldn't have taken this on.

But I couldn't stop. I had to know.











## Chapter 5 — The Obsession Begins

I labeled data. 30,000 images. It took nearly two months just to collect around 1,000 usable examples per digit class. By hand. Morning to night. I had no life. Just labeling, reshaping, fixing.

I trained the model. It failed.

I simulated the entire system in software—it still failed. Single digits worked. Plates didn't.

I was exhausted. Angry. Depressed. This was supposed to be a school project. It was turning into a life-consuming black hole.

Then I had a moment of clarity: What if I stop splitting the model? What if I make one unified CNN?

So I did.



## Chapter 6 — The Spark Returns

One model. Sliding window. One-layer CNN.

This wasn't just another experiment. This was the first step toward a real, modular solution. I built a simple CNN architecture: a single convolutional layer with a configurable number of filters, followed by ReLU, then a fully connected layer. Small—but powerful enough to test the pipeline.

But more importantly, it was parameterized. Filter count, layer parameters, and threshold values—all stored externally in .mif files. This meant I could retrain models, adjust parameters, and test new configurations without rewriting HDL.

I wanted this to be future-proof—not perfect. If more filters helped? I could retrain. If fewer filters worked? I could scale down. I didn't need to rebuild the logic. Just reconfigure.

Then I ran it in Python—a simulation of how my FPGA logic would behave.

One plate got detected: 5115555.

I didn't celebrate. I didn't even move. I just stared. It wasn't real hardware—not yet—but for the first time, the logic worked. A real number came out.

It gave me hope.





## Chapter 7 — Scaling the Unscalable

Now I knew it might have a chance. But building the real hardware version? That took everything.

The next step was to scale the system—to take what worked in simulation and make it real. That meant building a unified CNN model: shared filters, modular ReLU, dynamic feature storage, and a fully connected stage that could perform K×12×16×(N+1) INT multiplications—all inside a real FPGA.

It pushed the limits of everything I knew. The design was complex. The debugging was brutal. Timing violations, synthesis failures, logic mismatches. Over and over.

But then, finally—in ModelSim—I got it. 

-5115555.

This time, it wasn't Python. It was HDL simulation. ModelSim read a .mif file of the license plate image, and the output—character by character—emerged from my logic.

The hardware worked. I did it.

Yeah, it ran slower than the original concept—but 877μs latency was still respectable. Detection hit 39% full-plate accuracy. Real-time. Fully FPGA.

It wasn't perfect. But it was mine. And I accepted that.



## Chapter 8 — OS Meltdown, Round Two

With the OCR IP simulated and the CPU-side preprocessing running, the next step was figuring out how to make them talk. I needed to test the communication—not the full system yet, just the connection.

So I wrote basic HDL—a simple loopback logic where PIO_OUT = PIO_IN—just enough to confirm the planned PIO interfaces were accessible. Then I loaded it.

And it failed. Binary wouldn't load. The bridge was disabled. Back to square one.

Turns out, U-Boot didn't set up the handoff. Kernel configs were wrong. The OS I built? Still missing key pieces.

So I rebuilt it again. Toolchain. Kernel. U-Boot. Device tree.

Eventually—it worked.

## Chapter 9 — Crushing Crashes and Loopbacks

With the OS rebuilt and the loopback HDL ready, I tried again. This time, it wasn't about the OCR logic—it was just about proving that data could flow.

I ran the loopback test. And the OS crashed.

No logs. No warnings. Just a dead black screen.

So I patched the device tree. Cleaned up the SoC HDL. Recompiled everything. And tried again.

It looped back. It worked.

For the first time, HPS and FPGA shook hands—and this time, they didn't break each other.



## Chapter 10 — The Bridge Becomes a Brain

Now that the CPU and FPGA could finally talk, it was time to design the real interface—not just a handshake, but a protocol. I didn't want the system to just work. I wanted it to survive—and protect itself.

So I built AHIM—Accelerator Hot Interface Manager. Not just a bridge. A communication protocol. A watchdog. A guardian.

I didn't want a blind slave architecture. I wanted the FPGA to defend itself—to recognize bad commands, invalid configurations, and raise flags instead of silently failing. The system had to be able to say, "Something's wrong," not just wait for the CPU to notice.

I added runtime configurability. Want to ignore non-critical errors? Fine. Want to halt the system until the CPU acknowledges and resets? That too. This wasn't about performance alone—it was about control, resilience, and safety.

RX. TX. OCR_RX. Fault detection. Safe handshakes. Simulated. Verified.

Then the whole SoC. All the logic. It refused to synthesize.

I kept tweaking settings, trying different constraints, adjusting tool options. I retried synthesis again and again—different strategies, timing estimates, placement tweaks. Each attempt was another shot in the dark, hoping the logic would finally hold together.

Eventually—it built.





## Chapter 11 — When Integration Isn't Integration

I thought the hard part was over. The CPU worked. The FPGA worked. The AHIM protocol was solid. All the individual pieces were tested.

Now came the real question: Could they actually talk?

I built the API. Command interfaces, data transfer protocols, error handling. On paper, it was clean. The CPU would send commands, the FPGA would acknowledge, then image data would flow column by column.

I wrote test programs. Simple at first—send a basic command, get a response. That worked fine.

Then I tried sending actual image data. An entire license plate image, preprocessed and ready for OCR.

The command interface worked flawlessly. AHIM correctly handled the setup. But when it came to the actual data transmission? Disaster.

Every time I sent image data—say, 120 packets—the FPGA would suddenly close the access port after just 30. Sometimes 32. Sometimes less. I had no idea why.

I checked my logic. Again. And again. The CPU said it finished sending. The FPGA closed access—even when it hadn't actually received everything. Sometimes it acted as if it had already processed data it never got.

I tweaked timing. Added delays. Modified waitrequest logic. Nothing worked.

Even worse? Every minor change to the HDL took 30 minutes to synthesize. And every two or three builds, it failed anyway—not with errors, but simply because the design wouldn't fit.

So every fix became a gamble: a half-hour build, followed by another failure, followed by another theory.

Integration wasn't just hard—it was mysterious. I wasn't debugging logic. I was debugging something deeper—assumptions I didn't even know I was making.











## Chapter 12 — The 128-Bit Bus Lie

The breakthrough came when I stopped trusting the documentation and started trusting my eyes.

I had built my entire system assuming—as the documentation clearly stated—that the Avalon bridge supported clean 128-bit transfers. The docs and config tools made it sound simple: set the width, enable the ports, and you're good to go.

But it wasn't that simple.

As a student, I trusted what I read. I structured everything around that 128-bit assumption. My FPGA logic expected data to arrive in neat, predictable chunks. My CPU code sent it that way.

But the reality was different.

Eventually—after weeks of struggling with mysterious behavior—I learned to use Signal Tap properly. I could finally see the actual signals, not just what I thought they should be.

And that's when I discovered the truth: the bridge wasn't sending just one 128-bit word per transaction. It was bursting. Full burst transfers. Not synchronized like I expected—it was splitting my carefully planned data into chunks, managing its own flow control, and sending everything in ways my logic wasn't prepared for.

The hardware behaved unlike the documentation's description. No warning said, "this will break your assumptions about data flow." But it did.

My FPGA logic was designed for predictable, synchronized transfers. The actual hardware was sending unpredictable bursts.

That mismatch—between what the tools promised and what the hardware actually did—was the root of everything.















## Chapter 13 — First Contact

Now I understood the problem. The question was: could I fix it?

I redesigned the FPGA logic to handle burst transfers properly. Instead of expecting neat, predictable chunks, I built logic that could adapt to the hardware's actual behavior—variable bursts, unpredictable timing, flow control that I couldn't directly manage.

It was like learning a new language. Not the language I thought I was supposed to speak, but the language the hardware actually understood.

I rebuilt the interface. Tested it. And for the first time in weeks—it didn't crash.

Now came the real test. Not just "does it not crash"—but "does it actually work?"

I loaded a simple test image into the CPU. The same license plate image I'd been trying to send for weeks. The CPU preprocessed it, sliced it, normalized it, converted it to INT8.

Then it sent the data—column by column—through the redesigned interface to the FPGA.

The FPGA received it. Processed it through the full OCR pipeline. Ran the CNN. Applied thresholds. And sent back a result.

When I read that response? 5115555.

I had seen that number before—in simulation, in Python emulations, even inside Signal Tap. But this time, it wasn't abstract.

This time, it came from real communication. CPU to FPGA. FPGA to CPU. Through the actual hardware bus. No tricks, no shortcuts.

I couldn't believe it—so I stress-tested it.

I sent it again. And again. A hundred times. It never missed.

Then I tested malformed commands, invalid inputs, even triggered the watchdog logic on purpose.

Still—the system held.

AHIM worked. 

The burst interface worked. 

The FPGA didn't crash. 

The CPU didn't stall.

For the first time, they were truly talking.

The foundation was solid. Now I could build the system that would never die.



## Chapter 14 — The System That Stands Alone

Now came the final step—not just building blocks, not just bridges and logic and CNNs—but a real system.

I wasn’t designing for testbenches anymore. I was designing for autonomy.

The system had to boot from SD, load its own configuration, and operate without any human involvement. No SSH sessions. No terminal commands. No hardcoded values. Everything had to be dynamic—flexible, safe, and smart.

I gave it watchdog timers. If something stalled, it would recover.

I built in runtime-configurable modes—from file, not firmware.

I added error handling logic:

If the camera disconnected, switch to a fallback loop using stored demo images.

If OCR failed, retry.

If invalid results came back, log them, but keep going.

If something truly broke, it would soft-reset the affected part and try again.

The system was resilient by design. It didn’t just detect plates. It protected itself.

The host application became the orchestrator—slicing frames, handling flow, deciding how to act depending on success or failure. The FPGA? It never needed to change again. Its logic was solid, frozen in hardware. But the software? It became adaptable, alive.

Together, they were no longer a pipeline. They were a unit.

That was the moment I stopped thinking like a student running tests.

I had built a system designed to stand alone.









## Chapter 15 — The System That Never Dies

Then came the real test.

I let it run. No cable. No monitor. Just power.

One board. One system. Live.

The camera glitched. The connection failed.

The system noticed. It switched to demo mode, exactly as designed.

No crash. No panic. Just adaptation. It kept running, processing stored images in a loop.

OCR continued. Logs updated. Timers reset. Everything kept moving.

Then I walked away.

I didn’t stop it.

12 hours passed. Still running.

24 Still running.

48 Still.

100+ hours later— The system still alive.

No reboot. No crash. No human.

It processed image after image, looped through logic, handled fake plates and malformed inputs—and never broke.

The FPGA logic held. The AHIM protocol never misfired. The CPU never stalled.

The result? A complete, fully autonomous ALPR pipeline that didn’t just function—it persisted.

Not just working in a lab. Not just passing a test.

It ran. Alone.

After all the weeks of debugging, the failed integrations, the broken assumptions, the late nights decoding burst behavior and rewriting interfaces—

After all of it—I had built a machine that could live without me.

And that—more than benchmarks, or metrics, or flashy claims—is what made it real.









## Chapter 16 — Recognition and Legacy

It was never about perfection. It was about proving it could exist.

When I prepared for the final presentation, I got feedback from Some feedback questioned the practicality. "No flashy buzzwords," they said. "Why not just run this on a GPU? Your accuracy is too low. The FPGA part feels overengineered."

So I added context—not to impress them, but to communicate. Not to fake anything, but to speak their language, because otherwise they'd miss what was real:

A self-contained ALPR system. CNN inference at 877μs. Built from nothing—on hardware, by hand. A system that ran for over 100 hours without human intervention.

Not because I need to sell it. But because I need it to be seen. To be understood for what it really is.

After all the failures, miscompiles, synthesis crashes, and protocol mismatches...

After all the times I stared at Signal Tap trying to make sense of noise...

After all the times I nearly gave up...

And to think it all started with a vague idea—just a student, chasing hype.

Now the system runs on its own. That spark? It built something real.

Maybe someone will see it and say: "That's not just a student project. That's an engineer."



Dar Eshel Epstein — 2025

