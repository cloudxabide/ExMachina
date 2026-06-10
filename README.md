# ExMachina 

"A sovereign, air-gap-capable agentic AI platform with physical edge presence"

I am actually really stoked to be working on this homelab project.  It utilizes a number of things that are cool by themselves, but way cooler together

Adventures with physicalAI and Edge utilizing:
* Waveshare JetBot (Jetson Nano)
* NemoClaw (running on a workstation)
* NVIDIA DGX Spark  (providing Inference via vLLM)
* NemoTron (model of choice at the moment)

Eventually I would like to run NemoClaw in Kubernetes on my Harvester cluster.

![Wizarding, indeed](Images/Wizarding-MacStudio-DGX-Jetbot.jpeg)

---

Interesting discovery while working on this particular effort.  I began the planning and discussion for ExMachina with Claude using the Claude Desktop App and "Chat" - however, it was mentioning things like ARCHITECTURE.md - which made me wonder if there was a way to have a coordinated "chat history" along with my Git repo (and subsequent Claude Code history).  Short answer: 
> 4:16 PMClaude responded: They are independent — no shared state between them. Claude Code has no awareness of this chat history, and this chat can't see what's in your local repo or what you've done in Claude Code sessions.
