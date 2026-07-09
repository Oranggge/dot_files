import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	createBashTool,
	createEditTool,
	createFindTool,
	createGrepTool,
	createLsTool,
	createReadTool,
	createWriteTool,
} from "@earendil-works/pi-coding-agent";
import { Container, Text } from "@earendil-works/pi-tui";

type BuiltInTool = ReturnType<typeof createReadTool>;
type ToolFactory = (cwd: string) => BuiltInTool;

const factories: Record<string, ToolFactory> = {
	bash: createBashTool as ToolFactory,
	read: createReadTool as ToolFactory,
	edit: createEditTool as ToolFactory,
	write: createWriteTool as ToolFactory,
	grep: createGrepTool as ToolFactory,
	find: createFindTool as ToolFactory,
	ls: createLsTool as ToolFactory,
};

const toolCache = new Map<string, Record<string, BuiltInTool>>();

function getTools(cwd: string) {
	let tools = toolCache.get(cwd);
	if (!tools) {
		tools = Object.fromEntries(Object.entries(factories).map(([name, factory]) => [name, factory(cwd)]));
		toolCache.set(cwd, tools);
	}
	return tools;
}

function hidden() {
	return new Container();
}

function fallbackText(result: { content: Array<{ type: string; text?: string }> }, theme: any) {
	const text = result.content.find((part) => part.type === "text")?.text?.trim();
	return new Text(text ? theme.fg("toolOutput", text) : "", 0, 0);
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		// Start quiet; Ctrl+O still expands tools when debugging is needed.
		ctx.ui.setToolsExpanded(false);
	});

	for (const [name, factory] of Object.entries(factories)) {
		const metadataTool = factory(process.cwd());

		pi.registerTool({
			...metadataTool,
			name,
			// Render our own shell so an empty collapsed renderer removes the whole tool row.
			renderShell: "self",

			async execute(toolCallId, params, signal, onUpdate, ctx) {
				return getTools(ctx.cwd)[name].execute(toolCallId, params, signal, onUpdate);
			},

			renderCall(args, theme, context) {
				if (!context.expanded) return hidden();
				const tool = getTools(context.cwd)[name];
				return tool.renderCall?.(args, theme, context) ?? new Text(theme.fg("toolTitle", theme.bold(name)), 0, 0);
			},

			renderResult(result, options, theme, context) {
				if (!options.expanded) return hidden();
				const tool = getTools(context.cwd)[name];
				return tool.renderResult?.(result, options, theme, context) ?? fallbackText(result, theme);
			},
		});
	}
}
