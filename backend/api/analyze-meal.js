const MAX_IMAGE_BASE64_LENGTH = 8_000_000;

const nutritionSchema = {
  type: "object",
  properties: {
    name: { type: "string" },
    description: { type: "string" },
    calories: { type: "number", minimum: 0 },
    protein: { type: "number", minimum: 0 },
    carbs: { type: "number", minimum: 0 },
    fat: { type: "number", minimum: 0 },
    confidence: { type: "string", enum: ["低", "中", "高"] },
    portionNotes: { type: "string" },
    advice: { type: "string" }
  },
  required: [
    "name",
    "description",
    "calories",
    "protein",
    "carbs",
    "fat",
    "confidence",
    "portionNotes",
    "advice"
  ],
  additionalProperties: false
};

export default async function handler(request, response) {
  if (request.method !== "POST") {
    return response.status(405).json({ error: "Method not allowed." });
  }

  if (!process.env.OPENAI_API_KEY) {
    return response.status(500).json({ error: "Server is missing OPENAI_API_KEY." });
  }

  if (
    process.env.PLATE_APP_TOKEN &&
    request.headers["x-plate-token"] !== process.env.PLATE_APP_TOKEN
  ) {
    return response.status(401).json({ error: "Invalid app access token." });
  }

  const body = request.body ?? {};
  const description = typeof body.description === "string" ? body.description.trim() : "";
  const imageBase64 = typeof body.imageBase64 === "string" ? body.imageBase64 : null;

  if (!description && !imageBase64) {
    return response.status(400).json({ error: "Add a meal photo or description first." });
  }
  if (imageBase64 && imageBase64.length > MAX_IMAGE_BASE64_LENGTH) {
    return response.status(413).json({ error: "The meal photo is too large." });
  }

  const context = [
    `User description: ${description || "none"}`,
    `Body weight: ${numberOrUnknown(body.bodyWeightKg)} kg`,
    `Calories already logged today: ${numberOrUnknown(body.currentDailyCalories)} kcal`,
    `Estimated full-day burn: ${numberOrUnknown(body.estimatedDailyBurn)} kcal`
  ].join("\n");

  const content = [
    {
      type: "input_text",
      text: [
        context,
        "",
        "Estimate the visible or described serving actually eaten.",
        "Include cooking oil, sauces, drinks, and hidden calories when reasonably likely.",
        "Do not pretend the result is precise. Use confidence and portionNotes to state the main uncertainty.",
        "Return a short practical Chinese suggestion based on today's rough energy balance and protein."
      ].join("\n")
    }
  ];
  if (imageBase64) {
    content.push({
      type: "input_image",
      image_url: `data:image/jpeg;base64,${imageBase64}`,
      detail: "high"
    });
  }

  try {
    const openAIResponse = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: process.env.OPENAI_MODEL || "gpt-5-mini",
        store: false,
        reasoning: { effort: "low" },
        instructions: [
          "You estimate nutrition from meal photos and user descriptions.",
          "Reply in Simplified Chinese.",
          "This is a rough tracking aid, not medical advice.",
          "When uncertain, choose a realistic midpoint and explain the uncertainty.",
          "Keep advice to one or two concise sentences."
        ].join(" "),
        input: [{ role: "user", content }],
        text: {
          format: {
            type: "json_schema",
            name: "meal_nutrition_estimate",
            strict: true,
            schema: nutritionSchema
          }
        },
        max_output_tokens: 1200
      })
    });

    const result = await openAIResponse.json();
    if (!openAIResponse.ok) {
      console.error("OpenAI error", result);
      return response.status(502).json({ error: "OpenAI could not estimate this meal." });
    }

    const outputText = extractOutputText(result);
    if (!outputText) {
      return response.status(502).json({ error: "OpenAI returned no nutrition estimate." });
    }
    return response.status(200).json(JSON.parse(outputText));
  } catch (error) {
    console.error("Meal analysis failed", error);
    return response.status(500).json({ error: "Meal analysis failed." });
  }
}

function extractOutputText(result) {
  for (const item of result.output ?? []) {
    for (const content of item.content ?? []) {
      if (content.type === "output_text" && content.text) {
        return content.text;
      }
    }
  }
  return null;
}

function numberOrUnknown(value) {
  return Number.isFinite(value) ? Math.round(value) : "unknown";
}
